import Redis from 'ioredis';

interface CacheEntry {
  value: any;
  expiresAt: number | null;
}

class CacheManager {
  private redis: Redis | null = null;
  private memoryCache = new Map<string, CacheEntry>();
  private useMemory = true;

  constructor() {
    const redisUrl = process.env.REDIS_URL;
    if (redisUrl) {
      console.log(`[Cache] Found REDIS_URL. Initializing Redis client...`);
      try {
        this.redis = new Redis(redisUrl, {
          maxRetriesPerRequest: 1,
          connectTimeout: 5000,
          retryStrategy(times) {
            // Stop retrying Redis after 2 attempts to fall back to memory
            if (times > 2) {
              console.warn(`[Cache] Redis connection failed after ${times} retries. Falling back to in-memory cache.`);
              return null; 
            }
            return Math.min(times * 100, 1000);
          }
        });

        this.redis.on('connect', () => {
          console.log('🟢 [Cache] Connected to Redis successfully.');
          this.useMemory = false;
        });

        this.redis.on('error', (err) => {
          console.error('🔴 [Cache] Redis error:', err.message);
          this.useMemory = true;
        });
      } catch (e: any) {
        console.error('🔴 [Cache] Failed to initialize Redis client:', e.message);
        this.useMemory = true;
      }
    } else {
      console.log('💡 [Cache] No REDIS_URL provided. Running in-memory cache fallback.');
      this.useMemory = true;
    }
  }

  async get<T>(key: string): Promise<T | null> {
    if (!this.useMemory && this.redis) {
      try {
        const val = await this.redis.get(key);
        if (val === null) return null;
        return JSON.parse(val) as T;
      } catch (e: any) {
        console.warn(`[Cache] Redis get error: ${e.message}. Reading from memory cache.`);
      }
    }

    const entry = this.memoryCache.get(key);
    if (!entry) return null;

    if (entry.expiresAt && Date.now() > entry.expiresAt) {
      this.memoryCache.delete(key);
      return null;
    }

    return entry.value as T;
  }

  async set<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    const jsonStr = JSON.stringify(value);

    if (!this.useMemory && this.redis) {
      try {
        if (ttlSeconds) {
          await this.redis.set(key, jsonStr, 'EX', ttlSeconds);
        } else {
          await this.redis.set(key, jsonStr);
        }
        return;
      } catch (e: any) {
        console.warn(`[Cache] Redis set error: ${e.message}. Writing to memory cache.`);
      }
    }

    const expiresAt = ttlSeconds ? Date.now() + (ttlSeconds * 1000) : null;
    this.memoryCache.set(key, { value, expiresAt });
  }

  async del(key: string): Promise<void> {
    if (!this.useMemory && this.redis) {
      try {
        await this.redis.del(key);
        return;
      } catch (e: any) {
        console.warn(`[Cache] Redis del error: ${e.message}. Deleting from memory cache.`);
      }
    }

    this.memoryCache.delete(key);
  }

  /**
   * Delete keys matching a pattern, e.g. "user:cmqmp...:*"
   */
  async delPattern(pattern: string): Promise<void> {
    console.log(`[Cache] Invalidating cache pattern: "${pattern}"`);
    
    if (!this.useMemory && this.redis) {
      try {
        const keys = await this.redis.keys(pattern);
        if (keys.length > 0) {
          await this.redis.del(...keys);
        }
        return;
      } catch (e: any) {
        console.warn(`[Cache] Redis keys/del pattern error: ${e.message}. Invalidating memory cache.`);
      }
    }

    // Fallback: In-memory pattern check
    // e.g. "user:userId:*" matches startsWith("user:userId:")
    const isWildcard = pattern.endsWith('*');
    const prefix = isWildcard ? pattern.slice(0, -1) : pattern;

    for (const key of this.memoryCache.keys()) {
      const match = isWildcard ? key.startsWith(prefix) : key === prefix;
      if (match) {
        this.memoryCache.delete(key);
      }
    }
  }

  // Clear memory cache (useful for testing)
  clearMemory() {
    this.memoryCache.clear();
  }
}

export const cache = new CacheManager();
