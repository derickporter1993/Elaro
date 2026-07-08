# Loop Improvement Proposals

Observed by the audit loop; never self-applied. Derick reviews and applies.

## RUN 2026-07-08
- P-001 (tooling): package.json `engines.npm` says ">=10.0.0" but the overrides entry
  `"@babel/core": "$@babel/core"` fails on npm 10.9.7 with "Unable to resolve reference
  $@babel/core"; npm 11 resolves it fine. Either bump engines.npm to ">=11" or replace
  the `$` reference with the concrete spec "^7.29.7" so fresh CI/containers on npm 10
  can install.
- P-002 (docs accuracy): TrustCenterLinkService.generateUuid doc and the
  Trust_Center_Link__c.Link_Token__c field description both say the token comes from
  Crypto.getRandomUUID(), but the implementation derives it from Crypto.generateAesKey(128)
  (TrustCenterLinkService.cls:140-146). Align the comments with the implementation (or
  switch to Crypto.getRandomUUID() if org API version allows) so security review reads
  consistently.
- P-003 (loop rule): the loop template's working-branch rule (audit-loop/YYYYMMDD)
  can conflict with harness-designated branches in remote sessions. Suggest the template
  say: use the harness-designated branch when one is mandated, record the deviation in
  AUDIT-STATE.md.
- P-004 (scanner hygiene): consider adding a code-analyzer.yml disposition or a
  documented-suppression list for the 11 recurring ProtectSensitiveData Moderates so
  future runs diff against a known-FP baseline instead of re-triaging.
