// conduit_sse_parser.c
// ConduitCore
//
// Incremental SSE (Server-Sent Events) parser operating on UTF-8 byte buffers.
// No global state. Thread-safe when each parser instance is accessed by one thread.

#include "conduit_core.h"
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

// Internal dynamic string buffer
typedef struct {
    char *data;
    size_t len;
    size_t capacity;
} dyn_str_t;

static void dyn_str_init(dyn_str_t *s) {
    s->data = NULL;
    s->len = 0;
    s->capacity = 0;
}

static void dyn_str_free(dyn_str_t *s) {
    free(s->data);
    s->data = NULL;
    s->len = 0;
    s->capacity = 0;
}

static void dyn_str_clear(dyn_str_t *s) {
    s->len = 0;
}

static bool dyn_str_append(dyn_str_t *s, const char *data, size_t len) {
    if (len == 0) return true;
    size_t needed = s->len + len + 1;
    if (needed > s->capacity) {
        size_t new_cap = s->capacity ? s->capacity * 2 : 128;
        if (new_cap < needed) new_cap = needed;
        char *new_data = (char *)realloc(s->data, new_cap);
        if (!new_data) return false;
        s->data = new_data;
        s->capacity = new_cap;
    }
    memcpy(s->data + s->len, data, len);
    s->len += len;
    s->data[s->len] = '\0';
    return true;
}

static bool dyn_str_append_char(dyn_str_t *s, char c) {
    return dyn_str_append(s, &c, 1);
}

static const char *dyn_str_cstr(const dyn_str_t *s) {
    return s->data ? s->data : "";
}

// Parser internals
struct conduit_sse_parser {
    dyn_str_t current_id;
    dyn_str_t current_event;
    dyn_str_t current_data;
    int current_retry;      // -1 if not set
    bool has_id;
    bool has_event;
    bool has_data;

    // Persistent state
    dyn_str_t last_event_id;
    int reconnection_time;
};

conduit_sse_parser_t *conduit_sse_parser_create(void) {
    conduit_sse_parser_t *p = (conduit_sse_parser_t *)calloc(1, sizeof(conduit_sse_parser_t));
    if (!p) return NULL;

    dyn_str_init(&p->current_id);
    dyn_str_init(&p->current_event);
    dyn_str_init(&p->current_data);
    dyn_str_init(&p->last_event_id);
    p->current_retry = -1;
    p->has_id = false;
    p->has_event = false;
    p->has_data = false;
    p->reconnection_time = 3000;

    return p;
}

void conduit_sse_parser_destroy(conduit_sse_parser_t *parser) {
    if (!parser) return;
    dyn_str_free(&parser->current_id);
    dyn_str_free(&parser->current_event);
    dyn_str_free(&parser->current_data);
    dyn_str_free(&parser->last_event_id);
    free(parser);
}

static void reset_current_event(conduit_sse_parser_t *p) {
    dyn_str_clear(&p->current_id);
    dyn_str_clear(&p->current_event);
    dyn_str_clear(&p->current_data);
    p->current_retry = -1;
    p->has_id = false;
    p->has_event = false;
    p->has_data = false;
}

static void dispatch_if_needed(conduit_sse_parser_t *p,
                                conduit_sse_callback_t callback,
                                void *context) {
    // If we have no data and no explicit id/event, nothing to dispatch
    bool is_data_empty = (p->current_data.len == 0);
    bool is_retry_only = is_data_empty && !p->has_id && !p->has_event && !p->has_data;

    if (is_retry_only) {
        reset_current_event(p);
        return;
    }

    if (callback) {
        conduit_sse_event_t event;
        event.id = p->has_id ? dyn_str_cstr(&p->current_id) : NULL;
        event.event = p->has_event ? dyn_str_cstr(&p->current_event) : NULL;
        event.data = dyn_str_cstr(&p->current_data);
        event.retry = p->current_retry;

        callback(&event, context);
    }

    reset_current_event(p);
}

void conduit_sse_ingest_line(
    conduit_sse_parser_t *parser,
    const char *line,
    size_t length,
    conduit_sse_callback_t callback,
    void *context
) {
    if (!parser) return;

    // Normalize: strip trailing \r (from CRLF)
    while (length > 0 && line[length - 1] == '\r') {
        length--;
    }

    // Strip leading BOM
    if (length >= 3 && (unsigned char)line[0] == 0xEF &&
        (unsigned char)line[1] == 0xBB && (unsigned char)line[2] == 0xBF) {
        line += 3;
        length -= 3;
    }

    // Empty line → dispatch event
    if (length == 0) {
        dispatch_if_needed(parser, callback, context);
        return;
    }

    // Comment: starts with ':'
    if (line[0] == ':') {
        return;
    }

    // Parse field:value
    const char *colon = (const char *)memchr(line, ':', length);
    const char *field = line;
    size_t field_len;
    const char *value;
    size_t value_len;

    if (colon) {
        field_len = (size_t)(colon - line);
        value = colon + 1;
        value_len = length - field_len - 1;
        // Skip single leading space in value (per SSE spec)
        if (value_len > 0 && value[0] == ' ') {
            value++;
            value_len--;
        }
    } else {
        field_len = length;
        value = "";
        value_len = 0;
    }

    if (field_len == 5 && memcmp(field, "event", 5) == 0) {
        dyn_str_clear(&parser->current_event);
        dyn_str_append(&parser->current_event, value, value_len);
        parser->has_event = true;
    }
    else if (field_len == 4 && memcmp(field, "data", 4) == 0) {
        if (parser->current_data.len > 0) {
            dyn_str_append_char(&parser->current_data, '\n');
        }
        dyn_str_append(&parser->current_data, value, value_len);
        parser->has_data = true;
    }
    else if (field_len == 2 && memcmp(field, "id", 2) == 0) {
        // ID must not contain null byte
        bool has_null = false;
        for (size_t i = 0; i < value_len; i++) {
            if (value[i] == '\0') { has_null = true; break; }
        }
        if (!has_null) {
            dyn_str_clear(&parser->current_id);
            dyn_str_append(&parser->current_id, value, value_len);
            parser->has_id = true;
            // Update last event id
            dyn_str_clear(&parser->last_event_id);
            dyn_str_append(&parser->last_event_id, value, value_len);
        }
    }
    else if (field_len == 5 && memcmp(field, "retry", 5) == 0) {
        // Parse as positive integer with overflow guard (max ~24 days in ms)
        int ms = 0;
        bool valid = (value_len > 0);
        for (size_t i = 0; i < value_len && valid; i++) {
            if (value[i] >= '0' && value[i] <= '9') {
                if (ms > 214748364) { valid = false; break; } // prevent int overflow
                ms = ms * 10 + (value[i] - '0');
            } else {
                valid = false;
            }
        }
        if (valid && ms > 0) {
            parser->reconnection_time = ms;
            parser->current_retry = ms;
        }
    }
    // Unknown fields are ignored
}

void conduit_sse_finish(
    conduit_sse_parser_t *parser,
    conduit_sse_callback_t callback,
    void *context
) {
    if (!parser) return;

    // Only dispatch if we have non-empty data or explicit id/event
    if (parser->current_data.len > 0 || parser->has_id || parser->has_event) {
        dispatch_if_needed(parser, callback, context);
    }
}
