// conduit_line_buffer.c
// ConduitCore
//
// High-performance line buffer using a growable byte array with memchr()-based
// newline scanning. O(1) amortized line extraction via read pointer advancement
// (no memmove on every line like the Swift version's removeFirst).

#include "conduit_core.h"
#include <stdlib.h>
#include <string.h>

struct conduit_line_buffer {
    uint8_t *data;
    size_t capacity;
    size_t read_pos;   // Start of unread data
    size_t write_pos;  // End of written data
};

conduit_line_buffer_t *conduit_line_buffer_create(size_t initial_capacity) {
    conduit_line_buffer_t *buf = (conduit_line_buffer_t *)calloc(1, sizeof(conduit_line_buffer_t));
    if (!buf) return NULL;

    if (initial_capacity < 256) initial_capacity = 256;

    buf->data = (uint8_t *)malloc(initial_capacity);
    if (!buf->data) {
        free(buf);
        return NULL;
    }

    buf->capacity = initial_capacity;
    buf->read_pos = 0;
    buf->write_pos = 0;

    return buf;
}

void conduit_line_buffer_destroy(conduit_line_buffer_t *buf) {
    if (!buf) return;
    free(buf->data);
    free(buf);
}

// Compact the buffer if read_pos has advanced past half the capacity
static void maybe_compact(conduit_line_buffer_t *buf) {
    if (buf->read_pos > buf->capacity / 2 && buf->read_pos > 0) {
        size_t pending = buf->write_pos - buf->read_pos;
        if (pending > 0) {
            memmove(buf->data, buf->data + buf->read_pos, pending);
        }
        buf->read_pos = 0;
        buf->write_pos = pending;
    }
}

int conduit_line_buffer_append(conduit_line_buffer_t *buf, const uint8_t *data, size_t length) {
    if (!buf || length == 0) return 0;

    size_t needed = buf->write_pos + length;
    if (needed > buf->capacity) {
        // Try compacting first
        maybe_compact(buf);
        needed = buf->write_pos + length;

        if (needed > buf->capacity) {
            size_t new_cap = buf->capacity * 2;
            if (new_cap < needed) new_cap = needed;
            uint8_t *new_data = (uint8_t *)realloc(buf->data, new_cap);
            if (!new_data) return -1;
            buf->data = new_data;
            buf->capacity = new_cap;
        }
    }

    memcpy(buf->data + buf->write_pos, data, length);
    buf->write_pos += length;
    return 0;
}

int conduit_line_buffer_next_line(
    conduit_line_buffer_t *buf,
    char *line_out,
    size_t line_out_capacity,
    size_t *line_len
) {
    if (!buf) return 0;

    size_t pending = buf->write_pos - buf->read_pos;
    if (pending == 0) return 0;

    const uint8_t *start = buf->data + buf->read_pos;

    // Use memchr for fast newline scanning — this is the key optimization
    // over Swift's firstIndex(where:) which checks two conditions per byte
    const uint8_t *newline_lf = (const uint8_t *)memchr(start, '\n', pending);
    const uint8_t *newline_cr = (const uint8_t *)memchr(start, '\r', pending);

    // Find the earliest newline
    const uint8_t *newline = NULL;
    if (newline_lf && newline_cr) {
        newline = (newline_lf < newline_cr) ? newline_lf : newline_cr;
    } else {
        newline = newline_lf ? newline_lf : newline_cr;
    }

    if (!newline) return 0; // No complete line yet

    size_t line_bytes = (size_t)(newline - start);
    if (line_bytes >= line_out_capacity) return 0; // Caller buffer too small

    // Copy the line (without delimiter)
    memcpy(line_out, start, line_bytes);
    line_out[line_bytes] = '\0';
    *line_len = line_bytes;

    // Consume the line + delimiter
    size_t consume = line_bytes + 1;

    // Handle \r\n: if we consumed \r and next byte is \n, consume it too
    if (*newline == '\r') {
        size_t next_pos = buf->read_pos + consume;
        if (next_pos < buf->write_pos && buf->data[next_pos] == '\n') {
            consume++;
        }
    }

    buf->read_pos += consume;

    // Compact periodically
    maybe_compact(buf);

    return 1;
}

size_t conduit_line_buffer_pending(const conduit_line_buffer_t *buf) {
    if (!buf) return 0;
    return buf->write_pos - buf->read_pos;
}

size_t conduit_line_buffer_drain(conduit_line_buffer_t *buf, char *out, size_t out_capacity) {
    if (!buf) return 0;

    size_t pending = buf->write_pos - buf->read_pos;
    if (pending == 0) return 0;

    size_t to_copy = pending < out_capacity ? pending : out_capacity;
    memcpy(out, buf->data + buf->read_pos, to_copy);
    buf->read_pos += to_copy;

    return to_copy;
}
