#!/usr/bin/env bash

set -euo pipefail

PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-30432}"
PGDATABASE="${PGDATABASE:-airbyte_source_db}"
PGUSER="${PGUSER:-bootstrap_owner}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-sequra-platform}"
POSTGRES_NAMESPACE="${POSTGRES_NAMESPACE:-data-source}"
POSTGRES_SECRET_NAME="${POSTGRES_SECRET_NAME:-sequra-postgres-auth}"
POSTGRES_SECRET_KEY="${POSTGRES_SECRET_KEY:-password}"
CUSTOMERS_COUNT="${CUSTOMERS_COUNT:-120}"
TX_COUNT="${TX_COUNT:-1500}"
AIRBYTE_READER_ROLE="${AIRBYTE_READER_ROLE:-airbyte_reader}"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required but not installed." >&2
  exit 1
fi

if [[ -z "${PGPASSWORD:-}" ]]; then
  if command -v kubectl >/dev/null 2>&1; then
    PGPASSWORD="$(
      kubectl --context "${KUBE_CONTEXT}" -n "${POSTGRES_NAMESPACE}" \
        get secret "${POSTGRES_SECRET_NAME}" \
        -o "jsonpath={.data.${POSTGRES_SECRET_KEY}}" | base64 -d
    )"
    export PGPASSWORD
  else
    echo "PGPASSWORD not set and kubectl is not available to fetch it from Kubernetes Secret." >&2
    exit 1
  fi
fi

psql "host=${PGHOST} port=${PGPORT} dbname=${PGDATABASE} user=${PGUSER}" -v ON_ERROR_STOP=1 <<SQL
CREATE TABLE IF NOT EXISTS public.bank_customers (
  customer_id BIGSERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  country_code TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.card_transactions (
  transaction_id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES public.bank_customers(customer_id),
  card_last4 CHAR(4) NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'EUR',
  merchant TEXT NOT NULL,
  status TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL
);

INSERT INTO public.bank_customers (full_name, email, country_code, created_at)
SELECT
  'Customer_' || floor(random() * 1000000)::INT::TEXT || '_' || gs::TEXT,
  'customer_' || floor(extract(epoch FROM clock_timestamp()) * 1000)::BIGINT::TEXT || '_' || gs::TEXT || '@bankdemo.local',
  (ARRAY['ES','FR','DE','IT','PT'])[1 + floor(random() * 5)::INT],
  NOW() - (random() * INTERVAL '365 days')
FROM generate_series(1, ${CUSTOMERS_COUNT}) gs
ON CONFLICT (email) DO NOTHING;

INSERT INTO public.card_transactions (
  customer_id,
  card_last4,
  amount,
  currency,
  merchant,
  status,
  occurred_at
)
SELECT
  (1 + floor(random() * GREATEST((SELECT COUNT(*) FROM public.bank_customers), 1)))::BIGINT,
  lpad((floor(random() * 10000)::INT)::TEXT, 4, '0'),
  round((5 + random() * 2500)::NUMERIC, 2),
  'EUR',
  (ARRAY['SEQURA_PAYMENTS','ATM_WITHDRAWAL','ONLINE_STORE','SUPERMARKET','TRAVEL'])[1 + floor(random() * 5)::INT],
  (ARRAY['SETTLED','PENDING','DECLINED'])[1 + floor(random() * 3)::INT],
  NOW() - (random() * INTERVAL '60 days')
FROM generate_series(1, ${TX_COUNT});

GRANT SELECT ON TABLE public.bank_customers TO "${AIRBYTE_READER_ROLE}";
GRANT SELECT ON TABLE public.card_transactions TO "${AIRBYTE_READER_ROLE}";
SQL

echo "Generated bank demo data successfully:"
echo "- bank_customers: +${CUSTOMERS_COUNT} attempted rows"
echo "- card_transactions: +${TX_COUNT} rows"
