const fs = require('fs');
const path = require('path');

function sync() {
  const envPath = path.join(__dirname, '..', '.env');
  const schemaPath = path.join(__dirname, '..', 'prisma', 'schema.prisma');

  let dbUrl = '';
  try {
    if (fs.existsSync(envPath)) {
      const envContent = fs.readFileSync(envPath, 'utf8');
      const match = envContent.match(/^DATABASE_URL\s*=\s*["']?([^"'\r\n]+)/m);
      if (match) {
        dbUrl = match[1].trim();
      }
    }
  } catch (err) {
    console.error('Error reading .env file:', err);
  }

  if (!dbUrl) {
    dbUrl = process.env.DATABASE_URL || '';
  }

  dbUrl = dbUrl.trim();

  if (!fs.existsSync(schemaPath)) {
    console.error('Prisma schema file not found at:', schemaPath);
    return;
  }

  let schema = fs.readFileSync(schemaPath, 'utf8');
  const originalSchema = schema;

  if (dbUrl.startsWith('file:')) {
    // Local SQLite database
    schema = schema.replace(/provider\s*=\s*"postgresql"/g, 'provider = "sqlite"');
    console.log('Syncing Prisma schema to use "sqlite" provider.');
  } else if (dbUrl.startsWith('postgresql://') || dbUrl.startsWith('postgres://')) {
    // Cloud/Production PostgreSQL database
    schema = schema.replace(/provider\s*=\s*"sqlite"/g, 'provider = "postgresql"');
    console.log('Syncing Prisma schema to use "postgresql" provider.');
  } else {
    console.log('No matching database url prefix found. Keeping current provider.');
    return;
  }

  if (schema !== originalSchema) {
    fs.writeFileSync(schemaPath, schema, 'utf8');
    console.log('Prisma schema updated successfully.');
  } else {
    console.log('Prisma schema provider is already up to date.');
  }
}

sync();
