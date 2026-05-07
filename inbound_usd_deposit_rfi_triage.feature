# language: en
Feature: Inbound USD deposit RFI triage
  As a Kira compliance officer
  I want the Agentic KYT system to score every inbound USD deposit automatically
  So that I can proactively prevent fund freezes and resolve potential RFIs in minutes, not days

  Background:
    Given "CryptoFX México S.A." is an active Kira client with VASP licence status
    And their 30-day average inbound is "$100,000 USD per day" from a single known US counterparty
    And the RFI Trigger Score threshold is configured at 85

  Scenario: Known counterparty sends a wire transfer and funds are received by the Kira client
    # ── Sender side ──────────────────────────────────────────
    Given "Acme Capital LLC" is a pre-onboarded counterparty with identity and source-of-funds on file
    And "Acme Capital LLC" initiates a "$95,000 USD" SWIFT wire transfer to "CryptoFX México S.A."
    And the wire includes a valid sender reference and a memo matching a known invoice

    # ── Correspondent banking leg ─────────────────────────────
    When the SWIFT message is routed through Kira's correspondent bank
    And the funds settle into Kira's nostro account

    # ── Kira inbound detection ────────────────────────────────
    Then Kira's system detects the inbound deposit and creates a transaction record
    And the transaction is assigned a unique ID and timestamped

    # ── Agentic KYT scoring ───────────────────────────────────
    When the AI agent runs KYT and KYC scoring on the transaction
    Then the KYT score is low because the counterparty is known, the amount is within normal range, and the jurisdiction is low-risk
    And the KYC score is low because the client's documents and licence are current
    And the combined RFI Trigger Score is below the 85-point threshold

    # ── Auto-clearance ────────────────────────────────────────
    And the AI agent marks the transaction as "Low risk — auto-cleared"
    And no compliance officer review is required
    And the funds are released from Kira's nostro account to "CryptoFX México S.A."'s account

    # ── Client receives funds ─────────────────────────────────
    Then "CryptoFX México S.A." sees the credited balance in their Kira dashboard
    And the transaction appears in their account history with the sender name, amount, and timestamp
    And the Kira Compliance Console logs the transaction as "Auto-cleared" with the final RFI Trigger Score

  Scenario: Unknown counterparty with large amount deviation triggers Smart Invoice flow and funds are released
    Given a "$1,000,000 USD" SWIFT deposit arrives from "TechTrade HK Ltd"
    And "TechTrade HK Ltd" has no prior transaction history with Kira
    And the deposit is 10x above the client's 30-day average inbound
    When the AI agent runs KYT and KYC scoring on the deposit
    Then the RFI Trigger Score exceeds the 85-point threshold
    And the top KYT triggers include "new/unknown counterparty" and "amount deviation"
    And the transaction is marked as "RFI likely" in the Kira Compliance Console
    And the AI agent automatically sends a Smart Invoice link to "CryptoFX México S.A."
    And the transaction status is set to "Awaiting documentation"
    When "TechTrade HK Ltd" submits their company identity, a valid invoice, and source-of-funds documentation
    And the AI agent validates all submitted documents via OCR
    Then the RFI Trigger Score drops below the 85-point threshold
    And the funds are released to the client's account
    And "TechTrade HK Ltd" is created as a pre-onboarded counterparty in Kira's database
