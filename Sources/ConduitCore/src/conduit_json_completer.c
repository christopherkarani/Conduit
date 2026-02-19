// conduit_json_completer.c
// ConduitCore
//
// Completes partial JSON by computing the minimal suffix and outputting the
// full completed string (input truncated at the completion point + suffix).
// Operates directly on UTF-8 bytes with O(1) pointer arithmetic.

#include "conduit_core.h"
#include <string.h>
#include <stdbool.h>

// Internal result: completion suffix + where to apply it
typedef struct {
    const char *suffix;       // Static or stack-allocated suffix string
    size_t suffix_len;
    size_t end_offset;        // Offset in input where completion applies
    char suffix_buf[128];     // Stack buffer for dynamic suffixes
    bool found;
} completion_t;

static size_t skip_ws(const char *json, size_t len, size_t pos) {
    while (pos < len && (json[pos] == ' ' || json[pos] == '\t' ||
                          json[pos] == '\n' || json[pos] == '\r')) {
        pos++;
    }
    return pos;
}

// Forward declarations
static completion_t complete_value(const char *json, size_t len, size_t pos, int depth, int max_depth);
static size_t find_end_of_complete_value(const char *json, size_t len, size_t pos, int max_depth);

// Complete a string starting at pos (which should be '"')
static completion_t complete_string(const char *json, size_t len, size_t pos) {
    completion_t r = {0};
    if (pos >= len || json[pos] != '"') return r;

    size_t cur = pos + 1;
    bool escaped = false;

    while (cur < len) {
        char c = json[cur];
        if (c == '\\') {
            escaped = !escaped;
        } else if (c == '"' && !escaped) {
            return r; // String is complete, no completion needed
        } else {
            escaped = false;
        }
        cur++;
    }

    // String is incomplete — close it
    r.found = true;
    r.suffix = "\"";
    r.suffix_len = 1;
    r.end_offset = cur;
    return r;
}

// Complete a number starting at pos
static completion_t complete_number(const char *json, size_t len, size_t pos) {
    completion_t r = {0};
    size_t cur = pos;

    if (cur < len && json[cur] == '-') cur++;

    size_t after_sign = cur;

    // Bare minus at end
    if (cur >= len) {
        r.found = true;
        r.suffix = "0";
        r.suffix_len = 1;
        r.end_offset = cur;
        return r;
    }

    // "-." prefix
    if (json[cur] == '.') {
        r.found = true;
        r.suffix = "0.0";
        r.suffix_len = 3;
        r.end_offset = cur;
        return r;
    }

    // Integer digits
    while (cur < len && json[cur] >= '0' && json[cur] <= '9') cur++;

    // Decimal part
    if (cur < len && json[cur] == '.') {
        cur++;
        size_t frac_start = cur;
        while (cur < len && json[cur] >= '0' && json[cur] <= '9') cur++;
        if (cur == frac_start) {
            // Decimal point with no fraction digits
            r.found = true;
            r.suffix = "0";
            r.suffix_len = 1;
            r.end_offset = cur;
            return r;
        }
    }

    // Exponent part
    if (cur < len && (json[cur] == 'e' || json[cur] == 'E')) {
        cur++;
        if (cur < len && (json[cur] == '+' || json[cur] == '-')) cur++;
        if (cur >= len || json[cur] < '0' || json[cur] > '9') {
            r.found = true;
            r.suffix = "0";
            r.suffix_len = 1;
            r.end_offset = cur;
            return r;
        }
        while (cur < len && json[cur] >= '0' && json[cur] <= '9') cur++;
    }

    // Complete number — no completion needed
    return r;
}

// Complete a special value (true, false, null)
static completion_t complete_special(const char *json, size_t len, size_t pos,
                                      const char *value, size_t value_len) {
    completion_t r = {0};
    size_t cur = pos;
    size_t matched = 0;

    while (cur < len && matched < value_len) {
        if (json[cur] != value[matched]) return r; // Mismatch
        cur++;
        matched++;
    }

    if (matched == value_len) return r; // Fully matched, no completion

    // Partially matched — complete it
    r.found = true;
    r.suffix = value + matched;
    r.suffix_len = value_len - matched;
    r.end_offset = cur;
    return r;
}

// Complete an array starting at pos (which should be '[')
static completion_t complete_array(const char *json, size_t len, size_t pos, int depth, int max_depth) {
    completion_t r = {0};
    if (pos >= len || json[pos] != '[') return r;

    size_t cur = pos + 1;
    bool requires_comma = false;
    size_t last_valid = cur;

    cur = skip_ws(json, len, cur);

    if (cur >= len || json[cur] == ']') {
        r.found = true;
        r.suffix = "]";
        r.suffix_len = 1;
        r.end_offset = cur;
        return r;
    }

    while (cur < len) {
        if (json[cur] == ']') return r; // Array is complete

        if (requires_comma) {
            if (json[cur] == ',') {
                requires_comma = false;
                cur++;
                cur = skip_ws(json, len, cur);
                if (cur >= len) break;
                last_valid = cur;
            } else {
                r.found = true;
                r.suffix = "]";
                r.suffix_len = 1;
                r.end_offset = last_valid;
                return r;
            }
        }

        if (cur >= len) break;
        if (json[cur] == ']') return r;

        completion_t elem = complete_value(json, len, cur, depth + 1, max_depth);
        if (elem.found) {
            // Build composite suffix: elem completion + "]"
            r.found = true;
            size_t total = elem.suffix_len + 1;
            if (total < sizeof(r.suffix_buf)) {
                memcpy(r.suffix_buf, elem.suffix, elem.suffix_len);
                r.suffix_buf[elem.suffix_len] = ']';
                r.suffix_buf[total] = '\0';
                r.suffix = r.suffix_buf;
                r.suffix_len = total;
            } else {
                r.suffix = "]";
                r.suffix_len = 1;
            }
            r.end_offset = elem.end_offset;
            return r;
        }

        size_t end = find_end_of_complete_value(json, len, cur, max_depth);
        cur = end;
        last_valid = cur;
        requires_comma = true;
    }

    r.found = true;
    r.suffix = "]";
    r.suffix_len = 1;
    r.end_offset = last_valid;
    return r;
}

// Complete an object starting at pos (which should be '{')
static completion_t complete_object(const char *json, size_t len, size_t pos, int depth, int max_depth) {
    completion_t r = {0};
    if (pos >= len || json[pos] != '{') return r;

    size_t cur = pos + 1;
    bool requires_comma = false;
    size_t last_valid = cur;

    cur = skip_ws(json, len, cur);

    if (cur >= len || json[cur] == '}') {
        r.found = true;
        r.suffix = "}";
        r.suffix_len = 1;
        r.end_offset = cur;
        return r;
    }

    while (cur < len) {
        if (json[cur] == '}') return r;

        if (requires_comma) {
            if (json[cur] == ',') {
                requires_comma = false;
                cur++;
                cur = skip_ws(json, len, cur);
                if (cur >= len) break;
                last_valid = cur;
            } else {
                r.found = true;
                r.suffix = "}";
                r.suffix_len = 1;
                r.end_offset = last_valid;
                return r;
            }
        }

        if (cur >= len) break;
        if (json[cur] == '}') return r;

        // Key
        completion_t key_comp = complete_string(json, len, cur);
        if (key_comp.found) {
            r.found = true;
            const char *suffix = ": null}";
            size_t slen = 7;
            size_t total = key_comp.suffix_len + slen;
            if (total < sizeof(r.suffix_buf)) {
                memcpy(r.suffix_buf, key_comp.suffix, key_comp.suffix_len);
                memcpy(r.suffix_buf + key_comp.suffix_len, suffix, slen);
                r.suffix_buf[total] = '\0';
                r.suffix = r.suffix_buf;
                r.suffix_len = total;
            } else {
                r.suffix = "}";
                r.suffix_len = 1;
            }
            r.end_offset = key_comp.end_offset;
            return r;
        }

        size_t key_end = find_end_of_complete_value(json, len, cur, max_depth);
        if (key_end <= cur) {
            r.found = true;
            r.suffix = "}";
            r.suffix_len = 1;
            r.end_offset = last_valid;
            return r;
        }

        cur = key_end;
        last_valid = cur;

        // Colon
        cur = skip_ws(json, len, cur);
        if (cur >= len || json[cur] != ':') {
            r.found = true;
            // Need to provide ": null}"
            const char *suffix = ": null}";
            r.suffix = suffix;
            r.suffix_len = 7;
            r.end_offset = last_valid;
            return r;
        }
        cur++;
        last_valid = cur;

        // Value
        cur = skip_ws(json, len, cur);
        if (cur >= len) {
            r.found = true;
            r.suffix = "null}";
            r.suffix_len = 5;
            r.end_offset = last_valid;
            return r;
        }

        completion_t val_comp = complete_value(json, len, cur, depth + 1, max_depth);
        if (val_comp.found) {
            r.found = true;
            size_t total = val_comp.suffix_len + 1;
            if (total < sizeof(r.suffix_buf)) {
                memcpy(r.suffix_buf, val_comp.suffix, val_comp.suffix_len);
                r.suffix_buf[val_comp.suffix_len] = '}';
                r.suffix_buf[total] = '\0';
                r.suffix = r.suffix_buf;
                r.suffix_len = total;
            } else {
                r.suffix = "}";
                r.suffix_len = 1;
            }
            r.end_offset = val_comp.end_offset;
            return r;
        }

        size_t val_end = find_end_of_complete_value(json, len, cur, max_depth);
        cur = val_end;
        last_valid = cur;
        requires_comma = true;
    }

    r.found = true;
    r.suffix = "}";
    r.suffix_len = 1;
    r.end_offset = last_valid;
    return r;
}

static completion_t complete_value(const char *json, size_t len, size_t pos, int depth, int max_depth) {
    completion_t r = {0};
    if (depth >= max_depth) return r;

    pos = skip_ws(json, len, pos);
    if (pos >= len) return r;

    switch (json[pos]) {
        case '{': return complete_object(json, len, pos, depth, max_depth);
        case '[': return complete_array(json, len, pos, depth, max_depth);
        case '"': return complete_string(json, len, pos);
        case 't': return complete_special(json, len, pos, "true", 4);
        case 'f': return complete_special(json, len, pos, "false", 5);
        case 'n': return complete_special(json, len, pos, "null", 4);
        case '-':
        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9':
            return complete_number(json, len, pos);
        default:
            return r;
    }
}

// Find where a complete value ends (returns offset past the value)
static size_t find_end_of_complete_value(const char *json, size_t len, size_t pos, int max_depth) {
    pos = skip_ws(json, len, pos);
    if (pos >= len) return pos;

    // If value is incomplete, return its end
    completion_t c = complete_value(json, len, pos, 0, max_depth);
    if (c.found) return c.end_offset;

    switch (json[pos]) {
        case '"': {
            size_t cur = pos + 1;
            bool escaped = false;
            while (cur < len) {
                if (json[cur] == '\\') escaped = !escaped;
                else if (json[cur] == '"' && !escaped) return cur + 1;
                else escaped = false;
                cur++;
            }
            return cur;
        }
        case '{': case '[': {
            char open = json[pos];
            char close = (open == '{') ? '}' : ']';
            int level = 0;
            size_t cur = pos;
            bool in_str = false;
            bool esc = false;
            while (cur < len) {
                char ch = json[cur];
                if (in_str) {
                    if (ch == '\\') esc = !esc;
                    else if (ch == '"' && !esc) in_str = false;
                    else esc = false;
                } else {
                    if (ch == '"') { in_str = true; esc = false; }
                    else if (ch == open) level++;
                    else if (ch == close) { level--; if (level == 0) return cur + 1; }
                }
                cur++;
            }
            return cur;
        }
        case 't':
            if (pos + 4 <= len && memcmp(json + pos, "true", 4) == 0) return pos + 4;
            break;
        case 'f':
            if (pos + 5 <= len && memcmp(json + pos, "false", 5) == 0) return pos + 5;
            break;
        case 'n':
            if (pos + 4 <= len && memcmp(json + pos, "null", 4) == 0) return pos + 4;
            break;
        case '-': case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9': {
            size_t cur = pos;
            while (cur < len && (json[cur] == '-' || json[cur] == '+' ||
                                  json[cur] == '.' || json[cur] == 'e' ||
                                  json[cur] == 'E' ||
                                  (json[cur] >= '0' && json[cur] <= '9'))) {
                cur++;
            }
            return cur;
        }
        default:
            break;
    }
    return pos;
}

int64_t conduit_json_complete(
    const char *input,
    size_t input_len,
    char *output,
    size_t output_capacity,
    int max_depth
) {
    if (output_capacity < 1) return -1;

    if (input_len == 0) {
        output[0] = '\0';
        return 0;
    }

    if (max_depth < 1) max_depth = 64;

    completion_t c = complete_value(input, input_len, 0, 0, max_depth);

    if (!c.found) {
        output[0] = '\0';
        return 0;
    }

    // Output the FULL completed string: input[0..end_offset] + suffix
    size_t total = c.end_offset + c.suffix_len;
    if (total + 1 > output_capacity) return -1;

    memcpy(output, input, c.end_offset);
    memcpy(output + c.end_offset, c.suffix, c.suffix_len);
    output[total] = '\0';

    return (int64_t)total;
}
