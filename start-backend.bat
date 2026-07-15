@echo off
title Backend - AI Finance Coach
cd /d "%~dp0backend"

if not exist .env copy .env.example .env >nul

if not exist node_modules (
  echo === First run: installing backend dependencies ===
  call npm install
)

echo === Syncing database schema ===
call npm run db:push

if not exist .seeded (
  echo === Seeding demo data ^(categories + demo user^) ===
  call npm run db:seed
  type nul > .seeded
)

echo.
echo ============================================================
echo   Backend running:  http://localhost:4000/health
echo   Demo login:       demo@bestimove.ai / demo1234
echo   Press Ctrl+C to stop.
echo ============================================================
call npm run dev
