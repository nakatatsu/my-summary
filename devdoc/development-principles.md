# Development Principles

## General

In this project, good design is defined as being easy to edit in AI-driven development. This is primarily accomplished through prompt minimization, secondarily through traceability of intent, and thirdly through automatic context acquisition.

### Prompt Minimization

The best prompt contains everything necessary and nothing more. To achieve this, the scope of concern should be divided into the smallest possible units. The basic principles are as follows:

1. Separation of concerns
2. Encapsulation
3. Polymorphism

The directory structure should also be optimized accordingly. Specifically, work should be completed as much as possible within a specific directory (for example, at the module level), and sufficient context should be obtainable from within that directory alone. In other words, there should be no need to search for code or specifications in other directories.

### Traceability

Prompts must be clear. To facilitate later analysis or modification, intentions not obvious from the code should be easy to retrieve.

Common know-how should be stored in a fixed location — for example, coding standards.
Domain-specific intentions should be stored within each directory — for example, module specifications.

In addition to these stock-type documents, flow-type documents should also be stored.

### Automatic Context Acquisition

Context should be gathered autonomously by the AI as much as possible.
Examples include requirements, domain knowledge, generated artifacts, and test results.

To achieve this, the AI should be provided with appropriate permissions and capabilities. However, authority involving unacceptable risk must not be granted.

## Basic workflow with AI Driven

The foundation of this project is AI-driven development + SpecDriven.
The basic workflow is as follows. Documents for the development such as coding standards will be prepared separately.

1. Create or update the requirements in `spec.md` or `README.md` (must not be deleted).
2. Create or update the design in `plan.md` (must not be deleted).
3. Document the work steps in `task.md` (may be deleted).

Generally, a work follows as below.

1. Generation by AI
2. Mechanical checks (tools and automated tests)
3. Automated review by AI
4. Human review
5. Merge and release

For example,

1. Create an issue
2. Create the specification and code based on the context (spec.md + plan.md + task.md + coding-standard.md + MCP + instructions -> code). Related code and documents are kept in sync as much as possible.
3. Tool checks
4. Unit tests
5. Commit
6. AI review by another generative AI
7. Commit, push, and open a pull request.
8. Human review
9. Merge
10. Close the issue when all the PRs are finished
11. Automated tests and deployment via CI/CD
12. E2E tests

### To minimize inconsistencies between spec, plan, and code

* Keep documents DRY. Never maintain the same information in multiple places.
* Do not include unimportant details in the specification.
* Write in code if sufficient, not in the specification.
* Do not manually maintain summaries of code. If needed, generate them (e.g., terraform-docs).
* Do not define a mechanical priority between spec, plan, and code —
  for example, never change correct code to conform to a wrong specification.


## Deliverable-based

Evaluation is based on the deliverable, not the process.
The process serves as a guide, not a guarantee. Because real development is rarely linear, the process should be adjusted as necessary.

Ultimately, what matters is the quality of the deliverable.



