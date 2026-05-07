# language: en
Feature: Inbound USD deposit RFI triage
  As a Kira compliance officer
  I want the Agentic KYT system to score every inbound USD deposit automatically
  So that I can proactively prevent fund freezes and resolve potential RFIs in minutes, not days

  Background:
    Given "CryptoFX México S.A." is an active Kira client with VASP licence status
    And their 30-day average inbound is "$100,000 USD per day" from a single known US counterparty
    And the RFI Trigger Score threshold is configured at 85

  # ─────────────────────────────────────────────────────────
  # HAPPY PATH: low-risk deposit from known counterparty
  # ─────────────────────────────────────────────────────────

  Scenario: Known counterparty within normal range auto-clears
    Given a "$95,000 USD" SWIFT deposit arrives from "Acme Capital LLC"
    And "Acme Capital LLC" is a pre-onboarded counterparty with identity and source-of-funds on file
    When the AI agent runs KYT and KYC scoring on the deposit
    Then the RFI Trigger Score is below the 85-point threshold
    And the funds are automatically released to the client's account
    And the Kira Compliance Console shows the transaction as "Low risk — auto-cleared"
    And no manual review is required

  # ─────────────────────────────────────────────────────────
  # RFI TRIGGER PATH: unknown counterparty with amount deviation
  # ─────────────────────────────────────────────────────────

  Scenario: Unknown counterparty with large amount deviation triggers Smart Invoice flow
    Given a "$1,000,000 USD" SWIFT deposit arrives from "TechTrade HK Ltd"
    And "TechTrade HK Ltd" has no prior transaction history with Kira
    And the deposit is 10x above the client's 30-day average inbound
    When the AI agent runs KYT and KYC scoring on the deposit
    Then the RFI Trigger Score exceeds the 85-point threshold
    And the top KYT triggers include "new/unknown counterparty" and "amount deviation"
    And the transaction is marked as "RFI likely" in the Kira Compliance Console
    And the AI agent automatically sends a Smart Invoice link to "CryptoFX México S.A."
    And the transaction status is set to "Awaiting documentation"

  Scenario: Counterparty completes Smart Invoice flow and funds are released
    Given a transaction is in "Awaiting documentation" status for "CryptoFX México S.A."
    And a Smart Invoice link was forwarded to "TechTrade HK Ltd"
    When "TechTrade HK Ltd" submits their company identity via the Smart Invoice form
    And "TechTrade HK Ltd" uploads a valid invoice matching the $1,000,000 transfer amount
    And "TechTrade HK Ltd" provides a source-of-funds description
    And the AI agent validates all submitted documents via OCR
    Then the invoice amount matches the inbound transaction amount
    And the counterparty identity is verified as consistent across all documents
    And the RFI Trigger Score drops below the 85-point threshold
    And the funds are released to the client's account
    And "TechTrade HK Ltd" is created as a pre-onboarded counterparty in Kira's database

  Scenario: Smart Invoice link expires without a counterparty response
    Given a Smart Invoice link was sent "24 hours ago" for a high-score transaction
    And no documentation has been submitted by the counterparty
    When the Smart Invoice expiry timer triggers
    Then the compliance officer receives an escalation alert in the Kira Compliance Console
    And the transaction status is set to "Escalated — no response"
    And the officer action bar offers "Extend window", "Hold 24h", and "Close case"

  # ─────────────────────────────────────────────────────────
  # COMPLIANCE CONSOLE: officer review and action
  # ─────────────────────────────────────────────────────────

  Scenario: Compliance officer reviews an RFI-likely transaction in the console
    Given a transaction with an RFI Trigger Score of 91 is visible in the live transactions feed
    And the top KYT trigger is "structuring pattern" with a 95% relevancy
    When the compliance officer opens the transaction detail view
    Then the officer sees the overall RFI Trigger Score dial showing 91
    And the KYT score card shows its 70% weighted contribution to the total score
    And the KYC score card shows its 30% weighted contribution to the total score
    And the top 3 KYT triggers are listed by weighted impact in descending order
    And the action bar exposes "Clear funds", "Send Smart Invoice link", "Escalate to officer", and "Hold 24h"

  Scenario: Compliance officer sends Smart Invoice link from the console action bar
    Given the compliance officer is viewing a transaction detail with score 91
    When the officer selects "Send Smart Invoice link" from the action bar
    Then a Smart Invoice request is dispatched to the beneficiary Kira client
    And the transaction status updates to "Awaiting documentation"
    And the action is recorded in the compliance audit trail with officer name and timestamp

  Scenario: Compliance officer manually clears a flagged transaction
    Given a transaction was scored at 87 by the AI agent
    And the compliance officer has reviewed the full KYT and KYC score breakdown
    And the officer determines the transaction is legitimate based on known client context
    When the officer selects "Clear funds" from the action bar
    Then the officer is prompted to enter a mandatory justification note
    And upon confirmation the funds are immediately released to the client's account
    And the transaction status changes to "Manually cleared"
    And the justification and officer identity are recorded in the compliance audit trail

  # ─────────────────────────────────────────────────────────
  # CRITICAL RISK: sanctions match triggers block and SAR
  # ─────────────────────────────────────────────────────────

  Scenario: Sanctions match on counterparty triggers automatic block and SAR queue
    Given a "$250,000 USD" wire arrives from an entity matching the OFAC SDN sanctions list
    When the AI agent runs KYT and KYC scoring on the deposit
    Then the RFI Trigger Score reaches a critical level at or above 95
    And the transaction is immediately blocked
    And a Suspicious Activity Report is automatically queued for compliance review
    And the compliance officer is notified in the Kira Compliance Console
    And the funds cannot be released without explicit compliance officer approval

  # ─────────────────────────────────────────────────────────
  # KYT DRILL-DOWN: score transparency for the officer
  # ─────────────────────────────────────────────────────────

  Scenario: Officer drills into the KYT score breakdown
    Given the officer is on the transaction detail page for a high-scoring deposit
    When the officer navigates to the KYT drill-down view
    Then each KYT trigger is listed with its name, description, and a relevancy meter
    And each trigger shows a weighted contribution calculated as "score × relevancy"
    And the triggers are sorted by weighted impact in descending order
    And a formula summary at the top shows "Σ(score × relevancy)" across all triggers
    And a recommendation panel at the bottom suggests the next action based on the highest-weighted trigger
