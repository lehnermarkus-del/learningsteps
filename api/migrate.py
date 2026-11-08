import asyncio
import os
import asyncpg


async def migrate():
    from main import database_url
    conn = await asyncpg.connect(database_url())
    try:
        # Einmaliger, serialisierter Schema-Job; keine Migration in jedem API-Pod.
        async with conn.transaction():
            await conn.execute("SELECT pg_advisory_xact_lock(6382601)")
            with open(os.getenv("SCHEMA_FILE", "/app/schema.sql")) as schema:
                sql = "\n".join(line for line in schema if not line.startswith("\\"))
            await conn.execute(sql)
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(migrate())
