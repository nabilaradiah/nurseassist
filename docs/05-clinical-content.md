# 5. Clinical content

NurseAssist gives clinical advice, so this is the part of the code to change most carefully. **Any change to wound types, scoring, management text or specialist rules needs sign-off from the clinical supervisor at the Kulliyyah of Nursing**, recorded in the pull request.

## Sources

* **Wound Care Quick Reference** (slide from the Kulliyyah of Nursing). This gives the Type 1–8 typing algorithm and the management plan for each type. The management text in the app is copied from it.
* **HKL ward wound assessment chart.** The TIME(S) assessment form follows its order and options.

Keep a copy of the Quick Reference slide with the handover documents. It's the reference for checking the app.

## Wound types: the scoring

A wound's type is the sum of three TIME scores (`TimFactors` in `lib/models/wound_assessment.dart`):

| Factor | Score |
|---|---|
| **T**issue: necrotic tissue + slough **over 25 %** of the wound bed | 4, else 0 |
| **I**nfection: any signs (local or spreading) | 2, else 0 |
| **M**oisture: moderate / wet | 2. Dry / minimal scores 1 |

Type = T + I + M, which always lands in 1–8:

| Type | Over 25 % necrotic/slough | Infected | Wet | Severity in app | Specialist confirmation |
|---|---|---|---|---|---|
| 1 | no | no | no | Mild (recovering) | |
| 2 | no | no | yes | Mild | |
| 3 | no | yes | no | Moderate | **required** |
| 4 | no | yes | yes | Moderate-severe | **required** |
| 5 | yes | no | no | Moderate-severe | |
| 6 | yes | no | yes | Severe | **required** |
| 7 | yes | yes | no | Severe-critical | |
| 8 | yes | yes | yes | Critical | |

At exactly 25 % the app asks the nurse to decide. Edges and surrounding skin are recorded but **not scored**.

The same table runs backwards (`TimFactors.fromWoundType`): the app works out which factors the AI's type implies and tells the nurse which ones they disagree on, e.g. "Infection". Every saved TIME(S) assessment goes to the lecturer's queue, and the ones that disagree with the AI are listed first.

## Where the clinical content lives in code

| What | Where |
|---|---|
| Severity, characteristics, management plan per type, specialist flag | `lib/models/wound_types_database.dart`, the **single source**. The results screen and the saved AI result both read from it |
| Scoring and the TIME(S) form options | `TimFactors`, `TimeAssessment` in `lib/models/wound_assessment.dart` |
| Allergy → dressing conflict words | `_allergenToDressing` in `lib/screens/analysis_results_screen.dart` (iodine/povidone/betadine, silver/sulfadiazine, honey, alginate/seaweed, charcoal, hydrocolloid/pectin/gelatin, adhesive/plaster) |
| "No known allergies" phrases | `Patient.hasKnownAllergies` in `lib/models/patient.dart` |
| Normal ranges for vital signs | `lib/models/vital_reading.dart` |

`test/models/wound_types_database_test.dart` and `test/time_assessment_test.dart` lock this behaviour in. If you change clinical content on purpose, update the tests in the same pull request.

## Safety rules built into the app

* **No silent default type.** An invalid type throws an error. It is never quietly shown as Type 1, the mildest.
* **No guessed AI result.** If the model can't run, there is no AI type, and the nurse's TIME(S) sets it.
* **The AI prediction is never overwritten.** `modelPredictedType` stays as it was, and corrections are stored alongside it.
* **Specialist confirmation** for Types 3, 4 and 6: the nurse must confirm a specialist was notified before saving.
* **Allergy warnings** appear before the management plan, and the matching dressings are flagged.
* **Privacy checklist** before every photo.

## Open clinical questions

These need the supervisor's answer. Don't change the code until you have it:

1. Should **Types 7 and 8** (infected and over 25 % necrotic, the most severe) also require specialist confirmation? Today only 3, 4 and 6 do. That matches the training notebook's list, but it looks inconsistent with severity.
2. Does the management text in `wound_types_database.dart` match the Quick Reference slide **word for word**? It was copied by hand and hasn't been formally checked.
3. Is the allergy word list complete for the dressings the ward actually uses?
