-- ==============================================================================
-- MIGRATION STEP 1: 20260825_step1_payments_enums.sql
-- LexHub Platform — Payments & Consultations ENUM Types Registration
-- MUST BE EXECUTED & COMMITTED FIRST (PostgreSQL 55P04 Enum Isolation Rule)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- 2. EXTEND OR CREATE consultation_status ENUM
DO $$ BEGIN
    CREATE TYPE consultation_status AS ENUM (
        'pending',
        'awaiting_payment',
        'confirmed',
        'in_progress',
        'completed',
        'cancelled',
        'expired',
        'disputed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Idempotently add any missing values to existing consultation_status
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'awaiting_payment';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'confirmed';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'in_progress';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'completed';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'cancelled';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'expired';
ALTER TYPE consultation_status ADD VALUE IF NOT EXISTS 'disputed';


-- 3. CREATE payment_status ENUM
DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM (
        'pending',
        'processing',
        'paid',
        'failed',
        'refunding',
        'refunded',
        'partially_refunded'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'processing';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'paid';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'failed';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'refunding';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'refunded';
ALTER TYPE payment_status ADD VALUE IF NOT EXISTS 'partially_refunded';


-- 4. CREATE payout_status ENUM
DO $$ BEGIN
    CREATE TYPE payout_status AS ENUM (
        'pending',
        'scheduled',
        'paid',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE payout_status ADD VALUE IF NOT EXISTS 'pending';
ALTER TYPE payout_status ADD VALUE IF NOT EXISTS 'scheduled';
ALTER TYPE payout_status ADD VALUE IF NOT EXISTS 'paid';
ALTER TYPE payout_status ADD VALUE IF NOT EXISTS 'cancelled';


-- 5. CREATE payment_provider ENUM
DO $$ BEGIN
    CREATE TYPE payment_provider AS ENUM (
        'payme',
        'click',
        'uzum',
        'manual'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'payme';
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'click';
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'uzum';
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'manual';
