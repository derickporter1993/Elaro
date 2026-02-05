---
created: 2026-02-05T09:15
title: Add WITH USER_MODE to ElaroGraphIndexer queries
area: security
priority: P1
files:
  - force-app/main/default/classes/ElaroGraphIndexer.cls:42-47
  - force-app/main/default/classes/ElaroGraphIndexer.cls:53-56
---

## Problem

ElaroGraphIndexer.cls has SOQL queries that are missing WITH USER_MODE clause, which is a P1 blocking issue for AppExchange submission. The queries are:

1. PermissionSet query (lines 42-47)
2. FlowDefinitionView query (lines 53-56)

These queries should enforce user-mode security to comply with Salesforce security review requirements.

## Solution

Add `WITH USER_MODE` to both queries in ElaroGraphIndexer.cls:

1. Line 42-47: PermissionSet query for entity metadata
2. Line 53-56: FlowDefinitionView query for flow metadata

This is part of the 12 P1 blocking items that must be completed before AppExchange submission.
