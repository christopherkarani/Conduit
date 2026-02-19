// conduit_core.h
// ConduitCore
//
// Umbrella header for Conduit's C performance core.
// All functions operate on raw byte/float buffers with no heap allocation
// unless explicitly documented. Thread-safe: no global mutable state.

#ifndef CONDUIT_CORE_H
#define CONDUIT_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// MARK: - Vector Operations
// ============================================================================

/// Computes the dot product of two float vectors.
/// Returns 0 if count is 0.
float conduit_dot_product(const float *a, const float *b, size_t count);

/// Computes cosine similarity between two float vectors.
/// Returns 0 if either vector has zero magnitude or count is 0.
float conduit_cosine_similarity(const float *a, const float *b, size_t count);

/// Computes Euclidean distance between two float vectors.
/// Returns 0 if count is 0.
float conduit_euclidean_distance(const float *a, const float *b, size_t count);

/// Computes cosine similarity of `query` against each of `count` vectors in `vectors`.
/// Each vector has `dimensions` floats. Results written to `results` (must hold `count` floats).
void conduit_cosine_similarity_batch(
    const float *query,
    const float *vectors,
    size_t dimensions,
    size_t count,
    float *results
);

// ============================================================================
// MARK: - SSE Parser
// ============================================================================

/// Opaque SSE parser handle.
typedef struct conduit_sse_parser conduit_sse_parser_t;

/// A parsed Server-Sent Event.
typedef struct {
    const char *id;        // NULL if not present
    const char *event;     // NULL if not present (implies "message")
    const char *data;      // Event data payload (never NULL after dispatch, may be "")
    int retry;             // Retry interval in ms, or -1 if not set
} conduit_sse_event_t;

/// Callback invoked for each dispatched SSE event.
/// The event fields are valid only for the duration of the callback.
typedef void (*conduit_sse_callback_t)(const conduit_sse_event_t *event, void *context);

/// Creates a new SSE parser. Returns NULL on allocation failure.
conduit_sse_parser_t *conduit_sse_parser_create(void);

/// Destroys an SSE parser and frees all associated memory.
void conduit_sse_parser_destroy(conduit_sse_parser_t *parser);

/// Ingests a single line (without trailing newline). May invoke `callback` if
/// a complete event is dispatched (e.g., on empty line).
void conduit_sse_ingest_line(
    conduit_sse_parser_t *parser,
    const char *line,
    size_t length,
    conduit_sse_callback_t callback,
    void *context
);

/// Flushes any pending event at end-of-stream. May invoke `callback`.
void conduit_sse_finish(
    conduit_sse_parser_t *parser,
    conduit_sse_callback_t callback,
    void *context
);

// ============================================================================
// MARK: - JSON Repair
// ============================================================================

/// Repairs incomplete JSON by closing unclosed strings, arrays, and objects.
/// Removes trailing commas and incomplete key-value pairs.
///
/// `input`/`input_len`: the potentially incomplete JSON (UTF-8).
/// `output`: caller-allocated buffer to receive the repaired JSON.
/// `output_capacity`: size of `output` in bytes.
/// `max_depth`: maximum bracket nesting depth to track (e.g. 64).
///
/// Returns the number of bytes written to `output` (excluding NUL terminator),
/// or -1 if `output_capacity` is too small. Output is always NUL-terminated
/// when return value >= 0.
int64_t conduit_json_repair(
    const char *input,
    size_t input_len,
    char *output,
    size_t output_capacity,
    int max_depth
);

// ============================================================================
// MARK: - JSON Completer
// ============================================================================

/// Completes partial JSON by appending missing closing characters.
///
/// `input`/`input_len`: the potentially incomplete JSON (UTF-8).
/// `output`: caller-allocated buffer for the FULL completed JSON string
///           (input truncated at the completion point + suffix appended).
/// `output_capacity`: size of `output` in bytes.
/// `max_depth`: maximum nesting depth (e.g. 64).
///
/// Returns the number of bytes written to `output` (the full completed string),
/// or -1 if output_capacity is too small. Output is always NUL-terminated
/// when return value >= 0. Returns 0 if the JSON is already complete
/// (output is empty string; caller should use original input as-is).
int64_t conduit_json_complete(
    const char *input,
    size_t input_len,
    char *output,
    size_t output_capacity,
    int max_depth
);

// ============================================================================
// MARK: - Line Buffer
// ============================================================================

/// Opaque line buffer handle.
typedef struct conduit_line_buffer conduit_line_buffer_t;

/// Creates a line buffer with the given initial capacity.
/// Returns NULL on allocation failure.
conduit_line_buffer_t *conduit_line_buffer_create(size_t initial_capacity);

/// Destroys a line buffer and frees all associated memory.
void conduit_line_buffer_destroy(conduit_line_buffer_t *buf);

/// Appends `length` bytes from `data` to the buffer.
/// Returns 0 on success, -1 on allocation failure.
int conduit_line_buffer_append(conduit_line_buffer_t *buf, const uint8_t *data, size_t length);

/// Extracts the next complete line (delimited by \n, \r, or \r\n).
/// On success: writes the line (without delimiter) to `line_out`, sets `line_len`
///   to the number of bytes, and returns 1.
/// On no complete line available: returns 0 and does not modify outputs.
/// `line_out` must point to a buffer of at least `conduit_line_buffer_pending(buf)` bytes.
///
/// The delimiter bytes are consumed from the buffer.
int conduit_line_buffer_next_line(
    conduit_line_buffer_t *buf,
    char *line_out,
    size_t line_out_capacity,
    size_t *line_len
);

/// Returns the number of bytes currently buffered.
size_t conduit_line_buffer_pending(const conduit_line_buffer_t *buf);

/// Drains all remaining bytes into `out` (for end-of-stream).
/// Returns the number of bytes written.
size_t conduit_line_buffer_drain(conduit_line_buffer_t *buf, char *out, size_t out_capacity);

#ifdef __cplusplus
}
#endif

#endif // CONDUIT_CORE_H
