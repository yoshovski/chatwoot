from alembic import context
from cwai.db import engine
from cwai.schema import metadata

with engine().connect() as connection:
    context.configure(connection=connection, target_metadata=metadata)
    with context.begin_transaction():
        context.run_migrations()
