// conduit_vector_ops.c
// ConduitCore
//
// High-performance vector operations for embedding similarity computation.
// Uses Accelerate/vDSP on Apple platforms, scalar fallback elsewhere.

#include "conduit_core.h"
#include <math.h>

#ifdef CONDUIT_HAS_ACCELERATE
#include <Accelerate/Accelerate.h>
#endif

float conduit_dot_product(const float *a, const float *b, size_t count) {
    if (count == 0) return 0.0f;

#ifdef CONDUIT_HAS_ACCELERATE
    float result = 0.0f;
    vDSP_dotpr(a, 1, b, 1, &result, (vDSP_Length)count);
    return result;
#else
    float result = 0.0f;
    for (size_t i = 0; i < count; i++) {
        result += a[i] * b[i];
    }
    return result;
#endif
}

float conduit_cosine_similarity(const float *a, const float *b, size_t count) {
    if (count == 0) return 0.0f;

#ifdef CONDUIT_HAS_ACCELERATE
    float dot = 0.0f, normA = 0.0f, normB = 0.0f;
    vDSP_dotpr(a, 1, b, 1, &dot, (vDSP_Length)count);
    vDSP_dotpr(a, 1, a, 1, &normA, (vDSP_Length)count);
    vDSP_dotpr(b, 1, b, 1, &normB, (vDSP_Length)count);
#else
    float dot = 0.0f, normA = 0.0f, normB = 0.0f;
    for (size_t i = 0; i < count; i++) {
        dot += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
    }
#endif

    float denom = sqrtf(normA) * sqrtf(normB);
    return denom > 0.0f ? dot / denom : 0.0f;
}

float conduit_euclidean_distance(const float *a, const float *b, size_t count) {
    if (count == 0) return 0.0f;

#ifdef CONDUIT_HAS_ACCELERATE
    // diff = a - b, then compute sqrt(dot(diff, diff))
    float *diff = (float *)malloc(count * sizeof(float));
    if (!diff) {
        // Fallback to scalar on allocation failure
        float sum = 0.0f;
        for (size_t i = 0; i < count; i++) {
            float d = a[i] - b[i];
            sum += d * d;
        }
        return sqrtf(sum);
    }
    vDSP_vsub(b, 1, a, 1, diff, 1, (vDSP_Length)count);
    float sum_sq = 0.0f;
    vDSP_dotpr(diff, 1, diff, 1, &sum_sq, (vDSP_Length)count);
    free(diff);
    return sqrtf(sum_sq);
#else
    float sum = 0.0f;
    for (size_t i = 0; i < count; i++) {
        float d = a[i] - b[i];
        sum += d * d;
    }
    return sqrtf(sum);
#endif
}

void conduit_cosine_similarity_batch(
    const float *query,
    const float *vectors,
    size_t dimensions,
    size_t count,
    float *results
) {
    if (dimensions == 0 || count == 0) return;

    // Pre-compute query norm
#ifdef CONDUIT_HAS_ACCELERATE
    float query_norm_sq = 0.0f;
    vDSP_dotpr(query, 1, query, 1, &query_norm_sq, (vDSP_Length)dimensions);
#else
    float query_norm_sq = 0.0f;
    for (size_t i = 0; i < dimensions; i++) {
        query_norm_sq += query[i] * query[i];
    }
#endif
    float query_norm = sqrtf(query_norm_sq);

    if (query_norm == 0.0f) {
        for (size_t i = 0; i < count; i++) {
            results[i] = 0.0f;
        }
        return;
    }

    for (size_t v = 0; v < count; v++) {
        const float *vec = vectors + v * dimensions;

#ifdef CONDUIT_HAS_ACCELERATE
        float dot = 0.0f, vec_norm_sq = 0.0f;
        vDSP_dotpr(query, 1, vec, 1, &dot, (vDSP_Length)dimensions);
        vDSP_dotpr(vec, 1, vec, 1, &vec_norm_sq, (vDSP_Length)dimensions);
#else
        float dot = 0.0f, vec_norm_sq = 0.0f;
        for (size_t i = 0; i < dimensions; i++) {
            dot += query[i] * vec[i];
            vec_norm_sq += vec[i] * vec[i];
        }
#endif

        float vec_norm = sqrtf(vec_norm_sq);
        results[v] = vec_norm > 0.0f ? dot / (query_norm * vec_norm) : 0.0f;
    }
}
