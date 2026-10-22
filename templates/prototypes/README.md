# prototypes/

Static HTML prototypes, one folder per work item and version:

```
prototypes/<WORK-ITEM-ID>/v1/index.html
prototypes/<WORK-ITEM-ID>/v1/<screen>.html
prototypes/<WORK-ITEM-ID>/v2/…
```

Rules:

- Static HTML only: inline CSS, no build step, no external requests except fonts
  the product already uses.
- Each version is a record. Never overwrite or edit a previous version.
- `index.html` lists every screen and state with links and a short rationale.
- Show states (default, empty, loading, error, success, focus, disabled) and
  breakpoints. Realistic content, never lorem ipsum.
- Approving a version is recorded in Plane; only the approved version is built.
