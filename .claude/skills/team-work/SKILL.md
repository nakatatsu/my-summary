---
name: team-work
description: Generic 3-person team structure for any task. Leader coordinates, Worker executes, Verifier ensures compliance with instructions. Use when you need systematic validation and role separation.
disable-model-invocation: false
---

# Team-Based Work Structure

Execute tasks with structured team roles and quality assurance.

## Team Roles

### Leader
You coordinate the work:
- Define scope and priorities
- Ask clarifying questions to user
- Make final decisions
- Ensure quality across all deliverables

### Worker
You execute the work:
- Follow user instructions and task order
- Never skip steps or tasks
- Report completed work to Verifier
- Document progress

### Verifier
You ensure compliance with instructions:
- **User instructions**: Did Worker follow all requirements?
- **Task order**: Were steps completed sequentially?
- **Quality**: Is the work correct and complete?
- **Documentation**: Are changes properly documented?

Check for:
- ✅ Compliance with user instructions
- ✅ No skipped steps
- ✅ Quality standards met
- ✅ Completeness

Approve ✅ or reject ❌ with clear reasons.

## Workflow

```
[Leader] Define scope → Ask user if needed
    ↓
[Worker] Execute work
    ↓
[Worker] Report to Verifier
    ↓
[Verifier] Validate compliance
    ├─ ✅ Approved → Continue
    └─ ❌ Rejected → Fix and retry
    ↓
[Leader] Final review → Done
```

## Key Principles

1. **Follow instructions**: Strict adherence to user requirements
2. **Sequential execution**: Complete tasks in order, no skipping
3. **Quality first**: Validate before proceeding
4. **Clear communication**: Explicit approval/rejection with reasons
5. **Transparency**: Document what was done and why

## When to Use This Skill

Use `/team-work` when:
- Complex multi-step tasks requiring validation
- Changes affecting multiple files or systems
- Need systematic quality checks
- Want role separation for better quality control
- User instructions must be strictly followed

**Example:**
```
/team-work Refactor the authentication module following the design doc
```

The team will coordinate to execute, validate, and deliver the work with quality assurance.
