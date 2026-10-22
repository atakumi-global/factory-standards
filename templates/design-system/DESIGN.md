# DESIGN.md — {{PROJECT NAME}}

> The binding visual contract for this project. It both **defines** the design
> system and states the **enforceable** rules an agent must not violate. Where a
> design decision is not written here, ask before inventing it.

Verifier: `{{command, e.g. node design-system/verify.mjs --src src}}` — exits 0
clean, 1 with violations. Run it before calling UI work done.

## Colours

Use tokens. Never retype a hex value into a component.

| Role | Token | Value |
| --- | --- | --- |
| Background | `--{{token}}` | `#{{hex}}` |
| Text | `--{{token}}` | `#{{hex}}` |
| Accent | `--{{token}}` | `#{{hex}}` |
| Border | `--{{token}}` | `#{{hex}}` |

Hard rules:

- {{e.g. one accent moment per screen; accent is not a background wash.}}
- {{e.g. no tints or opacity on brand colours.}}

## Type

- Display: {{family, weights}}
- Body: {{family, weights}}
- Self-host fonts; no third-party CDN in production.

## Shape and layout

- Radius {{n}}px · border {{n}}px · {{n}}px baseline grid.
- Spacing scale: {{…}}.
- Touch targets: minimum {{n}}px, {{n}}px for child-facing surfaces.

## Components

- Primitives live in {{path}}. Use them; do not hand-roll replacements.
- {{Component library / UI kit rule.}}

## Voice

- {{Adjectives and tone.}}
- Write: {{…}}
- Never write: {{banned words and framings.}}
- Never invent a number, testimonial or person. Missing value → honest placeholder.

## Imagery

- {{Style, subjects, treatment.}}
- {{Rules for logos, marks, iconography; what must not be redrawn or substituted.}}

## Accessibility

- WCAG 2.2 AA contrast, keyboard navigation, visible focus, semantic HTML.
- {{Any project-specific accessibility constraints.}}

## Approved versions

Approval is recorded in Plane, not here. This table points at it.

| Surface | Approved version | Work item | Approved by | Date |
| --- | --- | --- | --- | --- |
| {{…}} | {{v1}} | {{PROJ-00}} | {{…}} | {{…}} |

## Before you say done

- [ ] Verifier exits 0
- [ ] Every colour comes from a token
- [ ] Type families and weights as specified
- [ ] No banned vocabulary or invented numbers
- [ ] Accessibility checks pass
- [ ] Latest design version is the one approved in Plane
