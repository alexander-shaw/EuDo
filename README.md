# EuDo
https://docs.google.com/document/d/1PcQ7OrmRV_dfHPgK_PWXjHShWLEHPrPt3WwKYnrx33w/edit?usp=sharing

## Methodology

### Tech Stack
 - Swift/SwiftUI
 - CoreData for local persistence; fully offline and local; no network requests.

### Requirements
 - Tasks belong to the current day and expire at end of day (EOD).
 - By default, the user only sees one day at a time (the current day); the user has no control over this.
 - No future dates, backlogs, or overdue tasks.

 ### States
 - In Progress (default)
 - Completed
 - Trashed
 - Times Up

 ### Out of Scope
 - User auth/accounts
 - Scheduling for future days
 - Complex settings screen

 ### Version Control
 - Good practice but not required.
 - Pushing to main branch because I am not working in a team setting and this is a prototype where clean-break changes are valid.
 - And since this app is not in production, I am assuming any data migrations are not necessary.