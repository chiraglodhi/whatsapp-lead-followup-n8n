-- Supabase / PostgreSQL schema for the WhatsApp lead follow-up system.
-- Reconstructed from the live project's catalog (columns, constraints, indexes) on 2026-10-22.
-- Run in the Supabase SQL Editor on an empty project. Not tested as a single script on a fresh
-- database; verify before relying on it. Column order is the live order.

create table public.leads (
  id                 uuid primary key default gen_random_uuid(),
  phone              text not null unique,                 -- E.164, e.g. +919876543210 (WF1 normalises)
  name               text,
  source             text,
  raw_payload        jsonb,                              
  opted_out          boolean not null default false,       -- STOP / UNSUBSCRIBE etc. Checked by WF3.
  score              text check (score in ('cold','warm','hot')),
  status             text not null default 'new'
                       check (status in ('new','contacted','qualifying','handoff','closed','error')),
  followup_count     integer not null default 0,           -- follow-ups sent since the lead last replied
  next_follow_up_at  timestamptz,                          -- NULL = nothing scheduled (parked, hot or done)
  created_at         timestamptz not null default now(),
  send_error         text,                                 -- why a send failed or a follow-up was parked
  preferred_language text default 'bilingual'              -- 'hi' | 'en' | 'bilingual'
);
-- Known gap: no updated_at on leads (project rules ask for one on updatable tables).

create table public.messages (
  id          uuid primary key default gen_random_uuid(),
  lead_id     uuid references public.leads(id) on delete cascade,  -- nullable: unknown-sender messages are logged without a lead
  direction   text not null check (direction in ('in','out')),
  content     text,
  created_at  timestamptz not null default now(),
  external_id text unique                                  -- Twilio MessageSid; dedup key for inbound webhooks
);

create table public.qualifications (
  lead_id         uuid primary key references public.leads(id) on delete cascade,
  budget          text,
  location        text,
  property_type   text,
  timeline        text,
  summary         text,
  updated_at      timestamptz not null default now(),
  visit_requested boolean default false
);
-- Known gap: qualifications has no created_at (project rules ask for one on every table).

-- Indexes. The live database has two overlapping indexes on messages(lead_id, created_at):
-- idx_messages_lead_time (created_at DESC) and messages_lead_id_created_at_idx (ASC).
-- One is redundant. The DESC one matches the "last 10 messages, newest first" query.
create index idx_messages_lead_time on public.messages (lead_id, created_at desc);

-- Row Level Security is ON for all three tables with ZERO policies, so the anon/authenticated roles
-- can read and write nothing. The n8n Supabase credential must therefore use the service_role key,
-- which bypasses RLS. That key must never reach a browser or this repository.
alter table public.leads          enable row level security;
alter table public.messages       enable row level security;
alter table public.qualifications enable row level security;
