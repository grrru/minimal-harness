---
name: greenfield-web-design
description: Design and build a new web interface when no Figma file, screenshot, design system, or other visual source of truth exists. Coordinate frontend-design for art direction, ImageGen and Build Web Apps for concepting and implementation, and Browser-first or Playwright-fallback QA. Use for greenfield landing pages, dashboards, web apps, and redesigns without a supplied design.
---

# Greenfield Web Design

Run one coordinated workflow:

```text
frontend-design
  → ImageGen + frontend-app-builder
  → frontend-testing-debugging
  → Browser first, Playwright only as fallback
```

Treat this skill as the router. Let each named skill own its specialty instead
of duplicating its full instructions.

## 1. Confirm the route

- Use this workflow only when no usable visual source of truth exists.
- If the user supplies Figma, screenshots, an established design system, or an
  approved mockup, treat that source as authoritative and use the appropriate
  fidelity workflow instead.
- Interpret "no screenshots" as no user-supplied design reference. Generated
  concept images and browser QA screenshots remain part of this workflow.
- Preserve the repository's framework, component system, and conventions unless
  the user explicitly asks for a replacement.

## 2. Ground the brief

Extract the product, audience, primary job, required content, core interaction,
responsive needs, technical constraints, and acceptance criteria.

Use Addy Osmani skills selectively:

- Ask only for missing information that would materially change the product.
  Otherwise choose and state a concrete subject, audience, and primary job, then
  continue with clearly labeled sample content where needed.
- Use `idea-refine` or `spec-driven-development` only when unresolved product
  scope would make implementation likely to diverge from the user's intent.
- Use `source-driven-development` when implementation decisions depend on
  current framework or library documentation.
- Do not load the entire Addy skill pack for one task.

## 3. Set the visual direction

Read and follow `frontend-design` before generating concepts or code.

Produce a compact internal design direction containing:

- one subject-specific visual thesis;
- a restrained color and typography system;
- the layout model and signature element;
- the content hierarchy and interaction priorities;
- one self-critique that removes a generic or templated choice.

Keep this direction as the visual contract for the rest of the task.

## 4. Concept and build

Read and follow `frontend-app-builder` from Build Web Apps. Give it the design
direction and the user's concrete requirements.

- Use the built-in `imagegen` skill by default for every full greenfield surface,
  including data-heavy dashboards. Generate a complete concept and any original
  raster assets that the visual direction needs. Do not use generated images as
  a substitute for code-native text, controls, icons, charts, or layout.
- Skip ImageGen only when the user explicitly opts out or ImageGen is
  unavailable. State the reason and preserve the same design-direction step.
- Request concept approval in Plan mode or when the user asked to compare or
  approve concepts first. Otherwise continue without adding a ceremonial pause.
- Build through shared tokens and focused components. Use Addy's
  `frontend-ui-engineering` only when Build Web Apps leaves a non-trivial
  component architecture or accessibility gap; normal responsive implementation
  alone is not a reason to load it.
- Preserve exact user-provided copy and information architecture. Do not invent
  product claims or present sample metrics as real data.

## 5. Verify in a real browser

Read and follow `frontend-testing-debugging` from Build Web Apps.

1. Start the actual application and identify its real URL.
2. Use the Browser plugin or built-in app browser first when available.
3. Use regular Playwright only when Browser is unavailable or unreliable, and
   record the fallback reason.
4. Exercise every meaningful control and core workflow.
5. Inspect console errors, failed requests, focus behavior, keyboard use,
   reduced motion, and desktop/mobile layouts.
6. Capture screenshots for the important states and compare them directly with
   the accepted concept or visual contract.
7. Fix mismatches and repeat the checks until no material visual or interaction
   defect remains.

Do not treat a successful build or static source review as visual verification.

## 6. Sign off

Report:

- the visual direction implemented;
- the core interaction path exercised;
- the Browser checks performed, or the exact Playwright fallback reason;
- the desktop and mobile viewports checked;
- any remaining intentional deviations or unverified behavior.

Do not claim completion without naming the evidence that supports it.
