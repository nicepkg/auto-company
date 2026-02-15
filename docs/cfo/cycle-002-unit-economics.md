# Cycle 002 Unit Economics - Security Questionnaire Autopilot

## Financial Conclusion
**GO, but only with immediate repricing before pilot sales.**  
At the original pricing hypothesis (`$1,500 onboarding + $499/mo + $75 overage`), service-assisted unit economics fail.  
At a value-based service-assisted price (`$2,000 onboarding + $1,800/mo includes 12 questionnaires + $150 overage`), the model is viable and clears SaaS benchmarks.

## Key Numbers and Calculations

### 1) Pricing Comparison (Original vs Required)
| Metric | Original Hypothesis | Required Pilot Pricing |
|---|---:|---:|
| Monthly revenue at 12 questionnaires | `$649` | `$1,800` |
| Variable cost at 12 questionnaires | `$368` | `$368` |
| Gross profit / account / month | `$281` | `$1,432` |
| Gross margin | `43.3%` | `79.6%` |
| CAC (fully loaded, assumed) | `$4,800` | `$4,800` |
| CAC payback | `17.1 months` | `3.35 months` |
| LTV (3.5% monthly churn) | `$8,033` | `$40,914` |
| LTV:CAC | `1.67x` | `8.52x` |

Formulas used:
- `Gross Margin = (Revenue - Variable Cost) / Revenue`
- `Payback (months) = CAC / Monthly Gross Profit`
- `LTV = ARPA * Gross Margin / Monthly Churn`
- `LTV:CAC = LTV / CAC`

### 2) Break-Even Thresholds (Required Pilot Pricing)
- Assumed fixed monthly cost (lean team): `$29,000/month`
- Ramen threshold (per operating rule):  
  `MRR > fixed cost` -> `29,000 / 1,800 = 16.1` -> **17 active customers**
- Gross-profit operating break-even:  
  `29,000 / 1,432 = 20.3` -> **21 active customers**

### 3) Onboarding Economics
- Onboarding fee: `$2,000`
- Assumed onboarding delivery cost: `$500`
- Onboarding gross profit: `$1,500`
- Effective CAC after onboarding contribution:  
  `4,800 - 1,500 = $3,300`
- Effective payback:  
  `3,300 / 1,432 = 2.3 months`

## Benchmark Comparison
| Metric | Result (Required Pricing) | Target | Status |
|---|---:|---:|---|
| Gross margin | `79.6%` | `>70%` | Pass |
| LTV:CAC | `8.52x` | `>3.0x` | Pass |
| CAC payback | `3.35 months` | `<12 months` | Pass |
| Churn assumption | `3.5% monthly` | `<3% ideal B2B` | Watch |

## Assumptions vs Confirmed Data
| Item | Value | Status |
|---|---|---|
| ICP = B2B SaaS (20-200 employees), security questionnaire bottleneck | As defined in cycle docs | Confirmed |
| Original pricing hypothesis (`$1,500 + $499/mo + $75 overage`) | From `docs/cto/cycle-001-brainstorm.md` | Confirmed |
| Average questionnaires per account per month | `12` | Assumption |
| Variable cost per questionnaire (AI + reviewer + QA) | `$24` | Assumption |
| Account-level monthly support variable cost | `$80` | Assumption |
| Fully loaded CAC | `$4,800` | Assumption |
| Monthly churn | `3.5%` | Assumption |
| Fixed monthly operating cost | `$29,000` | Assumption |

## Specific, Measurable Optimizations
1. **Reprice before pilots**: No contracts below `$1,500 MRR` for service-assisted scope.
2. **Adopt value metric**: Price by questionnaires/month; keep overage at `>= $150`.
3. **Protect margin**: Cap human review time to `<=15 minutes/questionnaire`; if exceeded for 2 weeks, increase overage or trim scope.
4. **Churn control gate**: If monthly churn is `>5%` for 2 consecutive months, pause growth spend and fix onboarding/quality.
5. **Acquisition efficiency gate**: If CAC rises above `$6,000`, require paid pilot/onboarding fee collection before full rollout.

## CFO Decision Gate
- **NO-GO** if we keep original monthly pricing (`$499` base).
- **GO** if we launch with required pilot pricing and enforce the margin/churn gates above.
