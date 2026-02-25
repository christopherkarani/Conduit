// conduit_json_repair.c
// ConduitCore
//
// Single-pass JSON repair on raw UTF-8 bytes. Closes unclosed strings,
// arrays, objects. Removes trailing commas and incomplete key-value pairs.
// No heap allocation beyond the caller-provided output buffer.

#include "conduit_core.h"
#include <string.h>
#include <stdbool.h>

// Bracket types for the stack
typedef enum { BRACKET_BRACE = 0, BRACKET_SQUARE = 1 } bracket_type_t;

// JSON context for determining if a trailing string is a key or array element
typedef enum { CTX_UNKNOWN = 0, CTX_OBJECT = 1, CTX_ARRAY = 2 } json_context_t;

// Helper: skip trailing whitespace from the end of the output
static size_t trim_trailing_whitespace(char *buf, size_t len) {
    while (len > 0 && (buf[len - 1] == ' ' || buf[len - 1] == '\t' ||
                        buf[len - 1] == '\n' || buf[len - 1] == '\r')) {
        len--;
    }
    return len;
}

// Helper: check if a byte is a hex digit
static bool is_hex_digit(char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

// Helper: remove partial unicode escape at end of output
// Looks for \uX, \uXX, \uXXX patterns
static size_t remove_partial_unicode_escape(char *buf, size_t len) {
    if (len < 2) return len;

    // Search the last 6 chars for a backslash
    size_t search_start = len > 6 ? len - 6 : 0;
    size_t backslash_pos = len; // sentinel

    for (size_t i = search_start; i < len; i++) {
        if (buf[i] == '\\') backslash_pos = i;
    }

    if (backslash_pos >= len) return len;
    if (backslash_pos + 1 >= len) return len;

    if (buf[backslash_pos + 1] == 'u') {
        // Count hex digits after \u
        size_t hex_count = 0;
        for (size_t i = backslash_pos + 2; i < len && is_hex_digit(buf[i]); i++) {
            hex_count++;
        }
        if (hex_count < 4) {
            return backslash_pos; // Remove the entire \uXX... sequence
        }
    }

    return len;
}

// Helper: find the innermost unmatched opener by scanning forward with string-awareness.
// A backward scan without string tracking would miscount brackets inside string literals
// (e.g. {"key": "[value"} — the '[' inside the string is not an array opener).
static json_context_t find_context(const char *buf, size_t len) {
    bracket_type_t stack[256];
    int depth = 0;
    bool in_string = false;
    bool escape_next = false;

    for (size_t i = 0; i < len; i++) {
        char c = buf[i];
        if (escape_next) {
            escape_next = false;
            continue;
        }
        if (in_string) {
            if (c == '\\') escape_next = true;
            else if (c == '"') in_string = false;
            continue;
        }
        switch (c) {
            case '"': in_string = true; break;
            case '{':
                if (depth < 256) stack[depth++] = BRACKET_BRACE;
                break;
            case '}':
                if (depth > 0) depth--;
                break;
            case '[':
                if (depth < 256) stack[depth++] = BRACKET_SQUARE;
                break;
            case ']':
                if (depth > 0) depth--;
                break;
            default:
                break;
        }
    }

    if (depth == 0) return CTX_UNKNOWN;
    return (stack[depth - 1] == BRACKET_BRACE) ? CTX_OBJECT : CTX_ARRAY;
}

// Helper: remove incomplete key-value pairs from end of output
static size_t remove_incomplete_kvp(char *buf, size_t len) {
    len = trim_trailing_whitespace(buf, len);

    // Pattern: trailing comma — remove it
    if (len > 0 && buf[len - 1] == ',') {
        len--;
        len = trim_trailing_whitespace(buf, len);
    }

    // Pattern: ends with colon (key without value) — remove key:
    if (len > 0 && buf[len - 1] == ':') {
        len--; // remove colon
        len = trim_trailing_whitespace(buf, len);

        // Now remove the quoted key
        if (len > 0 && buf[len - 1] == '"') {
            len--; // remove closing quote
            // Find opening quote
            while (len > 0 && buf[len - 1] != '"') {
                len--;
            }
            if (len > 0) len--; // remove opening quote

            // Remove preceding comma and whitespace
            len = trim_trailing_whitespace(buf, len);
            if (len > 0 && buf[len - 1] == ',') {
                len--;
            }
        }
    }

    // Pattern: ends with a quoted string that might be an incomplete key in object context
    if (len > 0 && buf[len - 1] == '"') {
        // Find the start of this string
        size_t close_quote = len - 1;
        size_t idx = close_quote;
        if (idx > 0) idx--; // skip past the closing quote

        while (idx > 0) {
            if (buf[idx] == '"') {
                // Check if escaped
                size_t backslash_count = 0;
                size_t check = idx;
                while (check > 0 && buf[check - 1] == '\\') {
                    backslash_count++;
                    check--;
                }
                if (backslash_count % 2 == 0) {
                    break; // Found unescaped opening quote
                }
            }
            idx--;
        }

        // Check what precedes this string
        size_t prev = idx;
        if (prev > 0) prev--;
        while (prev > 0 && (buf[prev] == ' ' || buf[prev] == '\t' ||
                             buf[prev] == '\n' || buf[prev] == '\r')) {
            prev--;
        }

        if (prev < len && buf[prev] == '{') {
            // Object start — this is definitely an incomplete key
            len = idx;
            len = trim_trailing_whitespace(buf, len);
        } else if (prev < len && buf[prev] == ',') {
            json_context_t ctx = find_context(buf, prev);
            if (ctx == CTX_OBJECT) {
                len = idx;
                len = trim_trailing_whitespace(buf, len);
                if (len > 0 && buf[len - 1] == ',') {
                    len--;
                }
            }
        }
    }

    return len;
}

// Helper: remove trailing commas before closing brackets in a completed JSON string.
// Safe for in-place use (output == input) because out_idx <= read_idx at every step.
// input is non-const to permit aliased in-place calls without UB.
static size_t remove_trailing_commas(char *input, size_t input_len,
                                      char *output, size_t output_capacity) {
    size_t out = 0;
    bool in_string = false;
    bool escape_next = false;

    for (size_t i = 0; i < input_len && out < output_capacity - 1; i++) {
        char c = input[i];

        if (escape_next) {
            escape_next = false;
            output[out++] = c;
            continue;
        }

        if (in_string) {
            if (c == '\\') escape_next = true;
            else if (c == '"') in_string = false;
            output[out++] = c;
            continue;
        }

        if (c == '"') {
            in_string = true;
            output[out++] = c;
            continue;
        }

        if (c == ',') {
            // Look ahead for whitespace + closing bracket
            size_t j = i + 1;
            while (j < input_len && (input[j] == ' ' || input[j] == '\t' ||
                                      input[j] == '\n' || input[j] == '\r')) {
                j++;
            }
            if (j < input_len && (input[j] == '}' || input[j] == ']')) {
                continue; // Skip this comma
            }
        }

        output[out++] = c;
    }

    return out;
}

int64_t conduit_json_repair(
    const char *input,
    size_t input_len,
    char *output,
    size_t output_capacity,
    int max_depth
) {
    if (max_depth < 1) max_depth = 1;
    if (output_capacity < 3) return -1; // Need at least "{}\0"

    // Skip leading/trailing whitespace from input
    size_t start = 0;
    while (start < input_len && (input[start] == ' ' || input[start] == '\t' ||
                                  input[start] == '\n' || input[start] == '\r')) {
        start++;
    }

    // Empty input → "{}"
    if (start >= input_len) {
        output[0] = '{';
        output[1] = '}';
        output[2] = '\0';
        return 2;
    }

    // Parser state
    bool in_string = false;
    bool escape_next = false;
    bracket_type_t bracket_stack[256]; // Use fixed stack (capped at 256 depth)
    int stack_depth = 0;
    int effective_max = max_depth < 256 ? max_depth : 256;

    // First pass: copy input to output while tracking state
    // Guard against underflow: we need at least (effective_max + 2) bytes for closers + NUL.
    if (output_capacity <= (size_t)(effective_max + 2)) return -1;
    size_t out = 0;
    size_t capacity_for_content = output_capacity - (size_t)(effective_max + 2); // Reserve space for closers + NUL

    for (size_t i = start; i < input_len && out < capacity_for_content; i++) {
        char c = input[i];

        if (escape_next) {
            escape_next = false;
            output[out++] = c;
            continue;
        }

        if (in_string) {
            if (c == '\\') {
                escape_next = true;
            } else if (c == '"') {
                in_string = false;
            }
            output[out++] = c;
            continue;
        }

        // Not in string
        switch (c) {
            case '"':
                in_string = true;
                break;
            case '{':
                if (stack_depth < effective_max) {
                    bracket_stack[stack_depth++] = BRACKET_BRACE;
                }
                break;
            case '}':
                if (stack_depth > 0) stack_depth--;
                break;
            case '[':
                if (stack_depth < effective_max) {
                    bracket_stack[stack_depth++] = BRACKET_SQUARE;
                }
                break;
            case ']':
                if (stack_depth > 0) stack_depth--;
                break;
            default:
                break;
        }

        output[out++] = c;
    }

    // If in string: handle partial unicode escape, remove trailing backslash, close quote
    if (in_string) {
        out = remove_partial_unicode_escape(output, out);
        if (escape_next && out > 0 && output[out - 1] == '\\') {
            out--;
        }
        if (out < output_capacity - 1) {
            output[out++] = '"';
        }
    }

    // Remove trailing whitespace and comma
    out = trim_trailing_whitespace(output, out);
    if (out > 0 && output[out - 1] == ',') {
        out--;
    }

    // Remove incomplete key-value pairs
    out = remove_incomplete_kvp(output, out);

    // Close open brackets
    for (int i = stack_depth - 1; i >= 0 && out < output_capacity - 1; i--) {
        // Before adding closer, remove trailing comma
        out = trim_trailing_whitespace(output, out);
        if (out > 0 && output[out - 1] == ',') {
            out--;
        }
        output[out++] = (bracket_stack[i] == BRACKET_BRACE) ? '}' : ']';
    }

    output[out] = '\0';

    // Final pass: remove trailing commas before existing closing brackets (in-place)
    size_t final_len = remove_trailing_commas(output, out, output, output_capacity);
    output[final_len] = '\0';

    return (int64_t)final_len;
}
