# EuDo

A minimal, fully offline, today-only todo app built in SwiftUI.  (Yes, the name is inspired by Eulerity, which itself comes from Euler.)

**Requirements:**
[https://docs.google.com/document/d/1PcQ7OrmRV_dfHPgK_PWXjHShWLEHPrPt3WwKYnrx33w/edit?usp=sharing](https://docs.google.com/document/d/1PcQ7OrmRV_dfHPgK_PWXjHShWLEHPrPt3WwKYnrx33w/edit?usp=sharing)

---

# Methodology

## Tech Stack

- Swift / SwiftUI
- UIKit strictly for native TextEditor component
- Core Data for local persistence
- Fully offline and local; no network requests
- @AppStorage / UserDefaults for lightweight preferences and UI state
- Developed in both Xcode and Cursor IDE

## Architecture

- MVVM architecture.
- This project only has one primary entity: TaskItem.
- View handles presentation.
- ViewModel handles task state, filtering, and user actions.
- Core Data handles local persistence.
- In larger projects with many entities, business rules, and relationships, Domain-Driven Design (DDD) may be more appropriate.

## Requirements

- New tasks belong to the current day and always expire, at most, by end of day (EOD).
- By default, the user only sees one day at a time: the current day.
- The user has no control over dates.
- No future dates, backlogs, or overdue tasks.

## Task States

- In Progress (default)
- Completed
- Trashed
- Time’s Up

## Out of Scope

- User authentication / accounts
- Scheduling for future days
- Cloud sync / networking
- Complex settings screens
- Multi-device persistence

# Approach

## iOS Architecture and Fundamentals

- SwiftUI-first architecture.
- MVVM architecture for a small, focused app with one main entity.
- Observable state and reactive UI updates.
- Separation of concerns between views, view models, models, and persistence logic.
- Native Apple frameworks where possible instead of unnecessary dependencies.
- Building around the assignment constraints rather than engineering features beyond scope.

## Product Constraints and Trade-Offs

- Leaning into the “today-only” constraint instead of fighting it.
- Simplicity over configurability.
- Fully offline design reduces complexity, latency, and external dependencies.
- Limited feature scope enables faster iteration and a more focused user experience.
- Some extensibility is intentionally sacrificed because the assignment explicitly rejects future planning, backlogs, and scheduling complexity.

## Code Clarity and Organization

- One class per file.
- Aiming for one view per file, with small, single-purpose supporting helpers and subviews that can be abstracted when they become larger/reusable.
- Consistent naming conventions and straightforward file organization.
- Favoring readability and maintainability over premature abstraction.
- Keeping logic close to where it is used unless reuse or complexity justifies separation.

## Handling of Time, State, and Persistence

- Core Data for local task storage.
- @AppStorage / UserDefaults to persist lightweight settings and filter preferences.
- Time-based state transitions driven by the current day boundary.
- Explicit task states instead of deleting historical meaning immediately.
- No server state, synchronization logic, or remote persistence concerns.

## Version Control

- Good practice, although not strictly required for the assignment.
- Pushing directly to the main branch because this is a solo prototype rather than a collaborative production system.
- Assuming clean-break changes are acceptable.
- Since the app is not in production, migration strategy and backwards compatibility concerns are intentionally disregarded.

## Agentic AI

I believe we are entering a third stage of computing.

First, computer was a human job title.  Then, people programmed computers.  Increasingly, people will oversee computers programming computers.

Newer and future agentic models operate completely offline and locally.  Even in air-gapped military systems, commercial laboratories, or highly regulated domains like the power grid, there will likely be some role for agents, and consumer/business software will probably see the greatest adoption.

Jack Dorsey’s argument for Block is compelling: AI systems handle repetitive, generalized work while people focus on edge cases, judgment, and oversight.  And as people solve edge cases, models receive better training data, and the cycle improves.

To me, this resembles previous technological transitions: cars replacing horses, higher-level programming languages abstracting lower-level ones (Python <-- C <-- Assembly), or moving from punch cards to IDEs.

Productivity is higher; hundreds of lines of working, valid code can be generated in seconds, so judgment is more valuable.

The risk could be something like *The Machine Stops* by E.M. Forster, but while some may fall behind by outsourcing their thinking, others will use AI to gain an edge.

I love this field more than ever!  I plan to pursue graduate study in AI.  If I were already an expert, I would not be applying for an internship; I consider my judgment intermediate, and I am seeking professional experience to continue improving it and continue in the direction of making a dent in the universe.

## EuDo's Future Work

- Adding a lightweight, local ML model to sort tasks for the user, potentially during a splash screen at app launch. Features could include: previous `sortOrder`, expiration `dateTime`, estimated total time, task state, and completion history.
- Adding a lightweight, local ML model to predict when the user is most likely to engage with notifications.  This would improve the app’s "Trigger" step, following Nir Eyal’s *Hooked Model*.
- Adding a cached library of verbs, such that if the user creates a task without an action verb, the app could suggest rewriting it with one.
- Supporting syncing/importing from other todo apps so users can bring in existing task data.
- LLM API integration for most features is overkill for this app’s scope.  One possible exception would be a voice assistant that lets users add tasks conversationally However, this would introduce cost, network requests, and additional architectural complexity, so it conflicts with the app’s current offline-first constraints.

## Areas of Improvement

- Additional testing coverage.
- More test-driven development where upfront structure is clear; for this prototype, I prioritized flexibility and iteration speed.
- More comprehensive handling of edge cases around day rollover and expiration logic.
- Refining UI polish, accessibility, and animations.
- More formal dependency injection or architecture layering if the project scope increased.
- DDD or a more domain-heavy architecture if the app expanded beyond one main entity.
- Data migration strategy and versioning if moving toward production.
- Expanded documentation and developer onboarding material.

