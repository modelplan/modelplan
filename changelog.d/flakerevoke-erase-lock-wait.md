Revoking or forgetting a local-history scope now waits up to two seconds for a background reader to release its lock, instead of failing the cleanup at once with a consent error when the two overlap.
