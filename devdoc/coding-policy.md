# Coding Policy

## MUST

Comply with every point below.

* Use meaningful names for variables and functions (e.g., good: `getUser()` / bad: `method1()`).
* Do not reuse a variable within the same scope.
* Assign one responsibility to one function. Do not pack multiple responsibilities into a single function. The same applies to classes (or “struct + methods” in Go) — follow the Single Responsibility Principle.
* Keep closely related data and behavior together in a class for high cohesion and clear separation of concerns.
  * Conversely, do not split strongly related elements across separate functions.
* Do not add variables or functions that the specification does not require (YAGNI principle).
* Do not expose a function externally unless it truly needs to be called from outside.
  * A public function must represent an external interface.
* For dependency injection, depend on interfaces, not concrete implementations.
* Never store sensitive information (e.g., API keys) in plain text within the project.
  * Fetch them at runtime from environment variables or external services such as SSM Parameter Store.
  * Encrypted storage is acceptable, but do not bundle the decryption key in the project.
* Even if two functions perform the same process, separate them when their purposes differ.
* Remove or comment out dead code that is no longer referenced.
* Provide unit tests for every function, and ensure all tests pass.
* Leave no TODOs or partially implemented code.
* Implement every detail stated in the specification.
* Write a one-line comment summarizing the purpose of each function. Argument explanations are unnecessary except in special cases.

## SHOULD

Comply unless you have a compelling reason not to.

* When an Entity requires domain-specific validation, perform it inside the Entity’s own methods.
* Struct fields should be unexported (lowercase) and initialized only via a constructor function.
* Access struct fields through getter methods; avoid setters.
* Each class (struct + methods) should work independently.
* Avoid hard-coding values.
  * Place frequently changing values in configuration; rarely changing values may be declared as package-level constants.
* Keep domain responsibilities out of utility packages.
* A class must:
  1. Explicitly receive all dependencies (via DI) — it should not secretly rely on any helper.
  2. Maintain a consistent responsibility.
* Even if a file exceeds 200 lines, do not place multiple classes (structs) in it.
  * If you have multiple classes in a file over 200 lines, split them into separate files.
* Do not swallow errors.
* Remove obsolete or incorrect comments.
* Do not write comments that merely restate the code (e.g., `int a // declare integer a`).

## Better (Nice to Have)

Comply if possible.

* Actively use Value Objects for variables representing important domain concepts.
* Use Value Objects for both arguments and return values when possible.
* Prefer pure functions that return results rather than causing side effects. Use pointers only when necessary (e.g., large slices or shared transactions).
* A function should have no more than five parameters.
  * More than five suggests too many responsibilities or insufficient aggregation.
* Prefer block statements over deep nesting where possible.
* Replace `switch`/`if-elseif` branching with interfaces and polymorphism when appropriate.
* Instead of flag parameters that toggle behavior inside a function, split the function.
* Name functions with a verb or verb + object.
* Use full words rather than abbreviations (e.g., `compensatingTransaction` instead of `ct`). Commonly accepted abbreviations like `db` are fine.
* Keep each function to 100 lines or fewer (logical lines; wrapped lines count as one).
* Don't use getters unnecessarily.
