# Mermaid Library Requirements

## 1. Core Library Scope

| ID      | Requirement                                                                                                               | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-001 | The product shall provide a Library where users can view, organize, open, and manage diagrams.                            |       P1 |
| LIB-002 | The Library shall serve as the primary home/dashboard for saved user content.                                             |       P1 |
| LIB-003 | The Library shall support creating a new diagram from the dashboard/library.                                              |       P1 |
| LIB-004 | The Library should support diagrams, presentations, templates, shared diagrams, and recently edited items.                |       P2 |
| LIB-005 | The Library should distinguish between personal content and workspace/team content.                                       |       P2 |
| LIB-006 | The Library should support both solo-user and team/workspace use cases.                                                   |       P2 |
| LIB-007 | The Library should act as a navigation hub into Code Editor, Visual Editor, Whiteboard, AI generation, and Presentations. |       P1 |
| LIB-008 | The Library should make saved Mermaid diagrams feel like living editable documents, not static exported images.           |       P1 |

## 2. Library Entry Points

| ID      | Requirement                                                                                  | Priority |
| ------- | -------------------------------------------------------------------------------------------- | -------: |
| LIB-009 | Users shall be able to access the Library after signing in.                                  |       P1 |
| LIB-010 | Users shall be able to return to the Library from the diagram editor.                        |       P1 |
| LIB-011 | Users shall be able to return to the Library from presentation editing or presentation mode. |       P2 |
| LIB-012 | Users shall be able to create a new diagram from the Library.                                |       P1 |
| LIB-013 | Users should be able to create a new presentation from the Library.                          |       P2 |
| LIB-014 | Users should be able to access sample diagrams from the Library or new-diagram flow.         |       P2 |
| LIB-015 | Users should be able to access AI diagram generation from the Library.                       |       P2 |
| LIB-016 | Users should be able to access recent diagrams directly from a home/dashboard view.          |       P1 |

## 3. New Diagram Creation

| ID      | Requirement                                                                                                                                                                                                                                   | Priority |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-017 | The Library shall provide a prominent “New diagram” action.                                                                                                                                                                                   |       P1 |
| LIB-018 | New diagram creation shall allow users to start from a blank diagram.                                                                                                                                                                         |       P1 |
| LIB-019 | New diagram creation should allow users to start from Mermaid AI.                                                                                                                                                                             |       P2 |
| LIB-020 | New diagram creation should allow users to start from sample diagrams.                                                                                                                                                                        |       P2 |
| LIB-021 | New diagram creation should allow users to choose a diagram type.                                                                                                                                                                             |       P2 |
| LIB-022 | New diagram creation should support common Mermaid diagram types such as flowchart, sequence, ER, class, state, mind map, timeline, user journey, Gantt, pie, quadrant, block, Git graph, and C4/architecture-style diagrams where supported. |       P2 |
| LIB-023 | New diagram creation should allow users to choose the initial editing mode: Code, AI, Visual Editor, or Whiteboard where available.                                                                                                           |       P2 |
| LIB-024 | The Library should support creating a diagram from pasted Mermaid source.                                                                                                                                                                     |       P2 |
| LIB-025 | The Library should support importing an `.mmd` Mermaid source file.                                                                                                                                                                           |       P2 |

## 4. Content Types

| ID      | Requirement                                                                                                 | Priority |
| ------- | ----------------------------------------------------------------------------------------------------------- | -------: |
| LIB-026 | The Library shall support Mermaid diagram documents.                                                        |       P1 |
| LIB-027 | The Library should support presentation documents.                                                          |       P2 |
| LIB-028 | The Library should support diagram templates or samples.                                                    |       P2 |
| LIB-029 | The Library should support image assets if the product allows image insertion in diagrams or presentations. |       P3 |
| LIB-030 | The Library should support icon-based diagrams where Mermaid icons are available.                           |       P2 |
| LIB-031 | The Library should distinguish editable source diagrams from exported static files.                         |       P1 |
| LIB-032 | The Library should distinguish local/private diagrams from shared/workspace diagrams.                       |       P1 |
| LIB-033 | The Library should distinguish diagrams generated by AI from manually created diagrams where useful.        |       P3 |

## 5. Diagram Cards / Rows

| ID      | Requirement                                                                                                     | Priority |
| ------- | --------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-034 | Each Library item shall display the diagram title.                                                              |       P1 |
| LIB-035 | Each Library item shall display the last modified date.                                                         |       P1 |
| LIB-036 | Each Library item should display the owner or creator.                                                          |       P2 |
| LIB-037 | Each Library item should display a diagram-type label or icon.                                                  |       P2 |
| LIB-038 | Each Library item should display a thumbnail preview of the rendered diagram.                                   |       P2 |
| LIB-039 | Each Library item should display sharing status.                                                                |       P2 |
| LIB-040 | Each Library item should display collaboration/comment status where available.                                  |       P2 |
| LIB-041 | Each Library item should display whether it is private, shared, team-owned, or externally shared.               |       P2 |
| LIB-042 | Each Library item should expose quick actions such as open, rename, duplicate, share, move, export, and delete. |       P1 |
| LIB-043 | Library item thumbnails should degrade gracefully when a diagram cannot be rendered.                            |       P1 |
| LIB-044 | Library item thumbnails should not expose private diagram content to unauthorized users.                        |       P1 |

## 6. Library Views

| ID      | Requirement                                                     | Priority |
| ------- | --------------------------------------------------------------- | -------: |
| LIB-045 | The Library shall provide a default list or grid of diagrams.   |       P1 |
| LIB-046 | The Library should support grid view.                           |       P2 |
| LIB-047 | The Library should support list/table view.                     |       P2 |
| LIB-048 | The Library should support a compact recent-files view.         |       P2 |
| LIB-049 | The Library should support a workspace/project view.            |       P2 |
| LIB-050 | The Library should support a shared-with-me view.               |       P2 |
| LIB-051 | The Library should support a created-by-me or owned-by-me view. |       P2 |
| LIB-052 | The Library should support a trash/archive view.                |       P2 |
| LIB-053 | The Library should support a templates/samples view.            |       P2 |
| LIB-054 | The Library should support a presentations view.                |       P2 |

## 7. Search

| ID      | Requirement                                                               | Priority |
| ------- | ------------------------------------------------------------------------- | -------: |
| LIB-055 | The Library shall support searching diagrams by title.                    |       P1 |
| LIB-056 | The Library should support searching Mermaid source content.              |       P2 |
| LIB-057 | The Library should support searching by diagram type.                     |       P2 |
| LIB-058 | The Library should support searching by owner/collaborator.               |       P2 |
| LIB-059 | The Library should support searching by comments where permissions allow. |       P3 |
| LIB-060 | The Library should support searching presentation titles and slide text.  |       P3 |
| LIB-061 | Search results should clearly show why each item matched.                 |       P2 |
| LIB-062 | Search should respect user permissions.                                   |       P1 |
| LIB-063 | Search should not reveal private diagrams or hidden metadata.             |       P1 |

## 8. Filtering

| ID      | Requirement                                                                              | Priority |
| ------- | ---------------------------------------------------------------------------------------- | -------: |
| LIB-064 | The Library shall support filtering by ownership or access state.                        |       P2 |
| LIB-065 | The Library should support filtering by diagram type.                                    |       P2 |
| LIB-066 | The Library should support filtering by modified date.                                   |       P2 |
| LIB-067 | The Library should support filtering by creation date.                                   |       P2 |
| LIB-068 | The Library should support filtering by shared/private status.                           |       P2 |
| LIB-069 | The Library should support filtering by workspace, project, folder, or team.             |       P2 |
| LIB-070 | The Library should support filtering by AI-generated diagrams.                           |       P3 |
| LIB-071 | The Library should support filtering by diagrams with unresolved comments.               |       P3 |
| LIB-072 | The Library should support filtering by diagrams used in presentations.                  |       P3 |
| LIB-073 | The Library should support filtering by diagrams with broken rendering or syntax errors. |       P3 |

## 9. Sorting

| ID      | Requirement                                                  | Priority |
| ------- | ------------------------------------------------------------ | -------: |
| LIB-074 | The Library shall support sorting by recently modified.      |       P1 |
| LIB-075 | The Library should support sorting by recently created.      |       P2 |
| LIB-076 | The Library should support sorting alphabetically by title.  |       P2 |
| LIB-077 | The Library should support sorting by owner.                 |       P3 |
| LIB-078 | The Library should support sorting by diagram type.          |       P3 |
| LIB-079 | The Library should support sorting by most recently opened.  |       P2 |
| LIB-080 | The Library should remember the user’s preferred sort order. |       P3 |

## 10. Organization: Folders, Projects, Workspaces

| ID      | Requirement                                                                                             | Priority |
| ------- | ------------------------------------------------------------------------------------------------------- | -------: |
| LIB-081 | The Library should allow diagrams to be organized into folders or projects.                             |       P2 |
| LIB-082 | The Library should allow users to create folders/projects.                                              |       P2 |
| LIB-083 | The Library should allow users to rename folders/projects.                                              |       P2 |
| LIB-084 | The Library should allow users to move diagrams between folders/projects.                               |       P2 |
| LIB-085 | The Library should support drag-and-drop organization where appropriate.                                |       P3 |
| LIB-086 | The Library should support workspace-level organization for teams.                                      |       P2 |
| LIB-087 | The Library should clearly show the current workspace/project/folder context.                           |       P1 |
| LIB-088 | The Library should prevent users from moving diagrams into locations where they lack permission.        |       P1 |
| LIB-089 | The Library should preserve links and shares when a diagram is moved, unless policy requires otherwise. |       P2 |

## 11. Open and Edit Behavior

| ID      | Requirement                                                                                                                  | Priority |
| ------- | ---------------------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-090 | Opening a diagram from the Library shall open it in the editor.                                                              |       P1 |
| LIB-091 | The Library should preserve the last-used editing mode for each diagram.                                                     |       P2 |
| LIB-092 | The Library should allow users to choose “Open in Code Editor” where code editing is supported.                              |       P2 |
| LIB-093 | The Library should allow users to choose “Open in Visual Editor” where the diagram type is visually supported.               |       P2 |
| LIB-094 | The Library should allow users to choose “Open in Whiteboard” where available.                                               |       P2 |
| LIB-095 | The Library should allow users to choose “Open in Presentation” for deck items.                                              |       P2 |
| LIB-096 | If the requested editor mode cannot support the diagram, the product shall fall back to code/preview mode without data loss. |       P1 |
| LIB-097 | Opening a diagram with syntax errors shall show the source and an error state rather than hiding the document.               |       P1 |

## 12. Rename, Duplicate, Delete, Archive

| ID      | Requirement                                                                                                               | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-098 | Users shall be able to rename diagrams they can edit.                                                                     |       P1 |
| LIB-099 | Users shall be able to duplicate diagrams they can access, where permitted.                                               |       P1 |
| LIB-100 | Users shall be able to delete diagrams they own or have permission to delete.                                             |       P1 |
| LIB-101 | The Library should support archive as a softer alternative to delete.                                                     |       P2 |
| LIB-102 | Deleted diagrams should move to trash before permanent deletion.                                                          |       P2 |
| LIB-103 | Users should be able to restore deleted diagrams from trash.                                                              |       P2 |
| LIB-104 | The Library shall confirm destructive delete actions.                                                                     |       P1 |
| LIB-105 | The Library should explain when a diagram cannot be deleted because of permissions or dependencies.                       |       P2 |
| LIB-106 | Duplicating a diagram should duplicate its source, title, theme, and visual settings.                                     |       P1 |
| LIB-107 | Duplicating a diagram should not automatically duplicate collaborator access unless the user chooses to preserve sharing. |       P2 |

## 13. Export from Library

| ID      | Requirement                                                                   | Priority |
| ------- | ----------------------------------------------------------------------------- | -------: |
| LIB-108 | Users should be able to export diagrams directly from the Library.            |       P2 |
| LIB-109 | Export shall support SVG where diagram export is supported.                   |       P1 |
| LIB-110 | Export shall support PNG where diagram export is supported.                   |       P1 |
| LIB-111 | Export shall support Mermaid source/MMD where source export is supported.     |       P1 |
| LIB-112 | The Library should support batch export for multiple selected diagrams.       |       P3 |
| LIB-113 | Export actions shall respect permissions.                                     |       P1 |
| LIB-114 | Export should show errors when a diagram cannot render or cannot be exported. |       P1 |
| LIB-115 | Exported filenames should use diagram titles and safe filename normalization. |       P2 |

## 14. Sharing from Library

| ID      | Requirement                                                                                                  | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------ | -------: |
| LIB-116 | Users shall be able to share diagrams they own or have permission to share.                                  |       P1 |
| LIB-117 | Sharing should support inviting collaborators by email where collaboration is available.                     |       P2 |
| LIB-118 | Sharing should support setting diagram permissions.                                                          |       P1 |
| LIB-119 | Sharing should support an Editor link where the product supports editor sharing.                             |       P1 |
| LIB-120 | Sharing should support an SVG link where the product supports SVG sharing.                                   |       P1 |
| LIB-121 | The Library should display whether an item is shared.                                                        |       P2 |
| LIB-122 | The Library should display whether an item is externally shared.                                             |       P2 |
| LIB-123 | Users should be able to revoke sharing from the Library.                                                     |       P2 |
| LIB-124 | Share actions shall respect plan limits and workspace policies.                                              |       P1 |
| LIB-125 | Shared items shall not expose private source, comments, or collaborator data beyond the viewer’s permission. |       P1 |

## 15. Collaboration Awareness

| ID      | Requirement                                                                                  | Priority |
| ------- | -------------------------------------------------------------------------------------------- | -------: |
| LIB-126 | The Library should show collaborator avatars or counts for shared diagrams.                  |       P2 |
| LIB-127 | The Library should show active collaboration state when a diagram is currently being edited. |       P3 |
| LIB-128 | The Library should show unresolved comment counts where comments are supported.              |       P2 |
| LIB-129 | The Library should show recent activity or last editor where useful.                         |       P2 |
| LIB-130 | The Library should support opening the Activity Feed for a diagram.                          |       P2 |
| LIB-131 | The Library should support filtering to diagrams with recent activity.                       |       P3 |
| LIB-132 | The Library should support “shared with me” and “shared by me” groupings.                    |       P2 |

## 16. Activity and History Integration

| ID      | Requirement                                                                    | Priority |
| ------- | ------------------------------------------------------------------------------ | -------: |
| LIB-133 | The Library should display last modified metadata for each diagram.            |       P1 |
| LIB-134 | The Library should display the last activity actor where permitted.            |       P2 |
| LIB-135 | The Library should provide access to a diagram’s revision history or timeline. |       P2 |
| LIB-136 | The Library should allow users to restore a recently deleted item from trash.  |       P2 |
| LIB-137 | The Library should show whether a diagram has unsynced or local-only changes.  |       P2 |
| LIB-138 | The Library should avoid showing overly noisy activity summaries.              |       P2 |

## 17. Sample Diagrams and Templates

| ID      | Requirement                                                                                                                                                  | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------: |
| LIB-139 | The Library should provide access to sample diagrams.                                                                                                        |       P2 |
| LIB-140 | Sample diagrams should include common supported diagram types such as class, ER, flowchart, mind map, quadrant, sequence, state, timeline, and user journey. |       P2 |
| LIB-141 | Users should be able to preview a sample before creating a copy.                                                                                             |       P2 |
| LIB-142 | Starting from a sample shall create an editable copy rather than modifying the original sample.                                                              |       P1 |
| LIB-143 | Templates should include title, diagram type, description, and preview.                                                                                      |       P2 |
| LIB-144 | The Library should support team-approved templates where team/workspace features exist.                                                                      |       P3 |
| LIB-145 | The Library should support favoriting templates.                                                                                                             |       P3 |

## 18. Favorites, Pins, and Recents

| ID      | Requirement                                                                 | Priority |
| ------- | --------------------------------------------------------------------------- | -------: |
| LIB-146 | The Library should support recent diagrams.                                 |       P1 |
| LIB-147 | The Library should support favoriting/starred diagrams.                     |       P2 |
| LIB-148 | The Library should support pinned diagrams or projects.                     |       P2 |
| LIB-149 | Favorites should be user-specific.                                          |       P2 |
| LIB-150 | Recent diagrams should be user-specific.                                    |       P2 |
| LIB-151 | The Library should allow users to quickly resume their last edited diagram. |       P2 |
| LIB-152 | The Library should support clearing or managing recent items.               |       P3 |

## 19. Presentations in the Library

| ID      | Requirement                                                                                  | Priority |
| ------- | -------------------------------------------------------------------------------------------- | -------: |
| LIB-153 | The Library should list presentation decks separately from diagrams or clearly label them.   |       P2 |
| LIB-154 | Presentation items should show title, modified date, owner, and linked diagram count.        |       P2 |
| LIB-155 | Users should be able to open a presentation from the Library.                                |       P2 |
| LIB-156 | Users should be able to create a presentation from selected diagrams.                        |       P3 |
| LIB-157 | The Library should show when a presentation references diagrams that have changed.           |       P3 |
| LIB-158 | The Library should show broken or inaccessible linked diagram references in presentations.   |       P3 |
| LIB-159 | Sharing a presentation from the Library should respect the permissions of embedded diagrams. |       P1 |

## 20. AI Integration in the Library

| ID      | Requirement                                                                                                           | Priority |
| ------- | --------------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-160 | The Library should allow users to start a new AI-generated diagram.                                                   |       P2 |
| LIB-161 | The Library should display AI-generated diagrams like normal editable diagrams after saving.                          |       P1 |
| LIB-162 | The Library should optionally label diagrams as AI-generated.                                                         |       P3 |
| LIB-163 | The Library should allow users to duplicate and refine AI-generated diagrams.                                         |       P2 |
| LIB-164 | The Library should allow users to access the prompt/history for AI-generated diagrams where retention policy permits. |       P3 |
| LIB-165 | AI actions from the Library shall respect plan limits, credits, and workspace AI policies.                            |       P1 |

## 21. Import

| ID      | Requirement                                                                                          | Priority |
| ------- | ---------------------------------------------------------------------------------------------------- | -------: |
| LIB-166 | The Library should support importing Mermaid source files.                                           |       P2 |
| LIB-167 | The Library should support importing pasted Mermaid source.                                          |       P2 |
| LIB-168 | Imported diagrams shall be validated before being saved as normal diagrams.                          |       P1 |
| LIB-169 | Import failures shall show syntax or compatibility errors.                                           |       P1 |
| LIB-170 | Imported diagrams should preserve source text where possible.                                        |       P1 |
| LIB-171 | Imported diagrams should allow the user to choose a title, folder/project, and workspace.            |       P2 |
| LIB-172 | The Library should detect duplicate imported files and ask whether to replace, duplicate, or cancel. |       P3 |

## 22. Batch Selection and Bulk Actions

| ID      | Requirement                                                                                    | Priority |
| ------- | ---------------------------------------------------------------------------------------------- | -------: |
| LIB-173 | The Library should support selecting multiple items.                                           |       P2 |
| LIB-174 | Bulk actions should include move, archive, delete, export, and change sharing where permitted. |       P3 |
| LIB-175 | Bulk delete shall require confirmation.                                                        |       P1 |
| LIB-176 | Bulk actions shall respect permissions per selected item.                                      |       P1 |
| LIB-177 | The Library should show partial-success results for bulk actions.                              |       P2 |
| LIB-178 | The Library should explain why individual items failed during bulk operations.                 |       P2 |

## 23. Workspace and Team Administration

| ID      | Requirement                                                                                                | Priority |
| ------- | ---------------------------------------------------------------------------------------------------------- | -------: |
| LIB-179 | The Library should support workspace switching for users who belong to multiple workspaces.                |       P2 |
| LIB-180 | Workspace libraries should show team-owned diagrams and presentations.                                     |       P2 |
| LIB-181 | Workspace libraries should respect member roles.                                                           |       P1 |
| LIB-182 | Admins should be able to manage workspace content visibility.                                              |       P2 |
| LIB-183 | Admins should be able to view shared and externally shared diagrams where policy permits.                  |       P2 |
| LIB-184 | Admins should be able to manage deleted or archived workspace content where policy permits.                |       P3 |
| LIB-185 | Workspace libraries should integrate with SSO and access control policies where enterprise features exist. |       P2 |

## 24. Permissions and Access Control

| ID      | Requirement                                                                                                    | Priority |
| ------- | -------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-186 | The Library shall only show content the current user is allowed to access.                                     |       P1 |
| LIB-187 | The Library shall prevent unauthorized users from opening private diagrams.                                    |       P1 |
| LIB-188 | The Library shall prevent unauthorized users from editing read-only diagrams.                                  |       P1 |
| LIB-189 | The Library shall prevent unauthorized users from exporting restricted diagrams.                               |       P1 |
| LIB-190 | The Library shall prevent unauthorized users from changing permissions.                                        |       P1 |
| LIB-191 | The Library should show clear permission labels such as Owner, Editor, Commenter, or Viewer where applicable.  |       P2 |
| LIB-192 | The Library should communicate when an action is unavailable because of role, workspace policy, or plan limit. |       P2 |
| LIB-193 | The Library should avoid exposing private thumbnails to users without access.                                  |       P1 |

## 25. Sync and Offline States

| ID      | Requirement                                                                                | Priority |
| ------- | ------------------------------------------------------------------------------------------ | -------: |
| LIB-194 | The Library should show sync status for cloud-backed diagrams.                             |       P2 |
| LIB-195 | The Library should show when a diagram has local changes not yet synced.                   |       P2 |
| LIB-196 | The Library should show when content is unavailable because the user is offline.           |       P2 |
| LIB-197 | The Library should allow opening locally available diagrams while offline where supported. |       P2 |
| LIB-198 | The Library should reconcile changes after reconnecting.                                   |       P3 |
| LIB-199 | The Library should clearly distinguish cloud documents from local-only drafts.             |       P2 |

## 26. Empty States

| ID      | Requirement                                                                                                   | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-200 | The Library shall show an empty state when the user has no diagrams.                                          |       P1 |
| LIB-201 | The empty state shall provide a clear “Create new diagram” action.                                            |       P1 |
| LIB-202 | The empty state should offer starting points such as AI generation, blank diagram, sample diagram, or import. |       P2 |
| LIB-203 | The empty state should explain what the Library is for.                                                       |       P2 |
| LIB-204 | Empty folders/projects should explain how to add or move diagrams.                                            |       P2 |
| LIB-205 | Empty search results should offer clear reset-filter and clear-search actions.                                |       P1 |
| LIB-206 | Empty shared-with-me views should explain that shared diagrams will appear there.                             |       P2 |

## 27. Error Handling

| ID      | Requirement                                                                                                    | Priority |
| ------- | -------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-207 | The Library shall show a loading state while content is loading.                                               |       P1 |
| LIB-208 | The Library shall show an error state if content cannot be loaded.                                             |       P1 |
| LIB-209 | The Library shall provide retry for load failures.                                                             |       P1 |
| LIB-210 | The Library should preserve already loaded content if refresh fails.                                           |       P2 |
| LIB-211 | The Library shall show permission errors separately from network errors.                                       |       P2 |
| LIB-212 | The Library should handle deleted owners/collaborators gracefully.                                             |       P2 |
| LIB-213 | The Library should handle missing thumbnails gracefully.                                                       |       P1 |
| LIB-214 | The Library should handle diagrams that fail to render without hiding the source document.                     |       P1 |
| LIB-215 | The Library should show clear failure messages for rename, duplicate, move, export, share, and delete actions. |       P1 |

## 28. Accessibility

| ID      | Requirement                                                                                                  | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------ | -------: |
| LIB-216 | The Library shall be keyboard accessible.                                                                    |       P1 |
| LIB-217 | Library cards and rows shall expose accessible names.                                                        |       P1 |
| LIB-218 | Diagram thumbnails shall include accessible labels or be hidden from assistive technologies when decorative. |       P1 |
| LIB-219 | Search, filter, sort, and view controls shall be accessible.                                                 |       P1 |
| LIB-220 | Selection controls shall be accessible.                                                                      |       P1 |
| LIB-221 | Context menus shall be keyboard accessible.                                                                  |       P1 |
| LIB-222 | Empty, loading, and error states shall be announced appropriately.                                           |       P1 |
| LIB-223 | Shared/private status shall not rely on color alone.                                                         |       P1 |
| LIB-224 | Relative timestamps should expose absolute timestamps to assistive technologies.                             |       P2 |

## 29. Performance and Scale

| ID      | Requirement                                                                                     | Priority |
| ------- | ----------------------------------------------------------------------------------------------- | -------: |
| LIB-225 | The Library shall support pagination, lazy loading, or virtualized lists for large collections. |       P1 |
| LIB-226 | The Library should load recent content quickly before loading all metadata.                     |       P2 |
| LIB-227 | Thumbnail generation should not block Library interaction.                                      |       P1 |
| LIB-228 | Search and filtering should remain responsive for large libraries.                              |       P2 |
| LIB-229 | The Library should cache thumbnails and metadata where appropriate.                             |       P2 |
| LIB-230 | The Library should support incremental refresh.                                                 |       P2 |
| LIB-231 | The Library should avoid re-rendering every diagram thumbnail on every load.                    |       P1 |

## 30. Plan Gating

| ID      | Requirement                                                                                                                         | Priority |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------- | -------: |
| LIB-232 | The Library should respect plan limits for diagram count, team collaboration, sharing, AI, and workspace features.                  |       P1 |
| LIB-233 | The Library should show clear upgrade messaging for gated actions.                                                                  |       P2 |
| LIB-234 | The Library should distinguish unavailable features from disabled permissions.                                                      |       P2 |
| LIB-235 | Free-tier limitations should not block users from accessing their existing diagrams unless required by policy.                      |       P1 |
| LIB-236 | Team/Enterprise-only features such as SSO, advanced permissions, audit, or admin controls should be visible only where appropriate. |       P2 |
| LIB-237 | The Library should avoid hard-coding plan names or quotas that may change over time.                                                |       P1 |

## 31. Recommended MVP Scope

| Area          | MVP Requirement                                             |
| ------------- | ----------------------------------------------------------- |
| Home          | Library/dashboard showing saved diagrams                    |
| Create        | New diagram button                                          |
| Open          | Open diagram into editor                                    |
| Item metadata | Title, modified date, diagram type, thumbnail               |
| Organization  | Recent diagrams and basic folders/projects                  |
| Search        | Search by title                                             |
| Sort          | Sort by recently modified and title                         |
| Actions       | Rename, duplicate, delete, export, share                    |
| Export        | PNG, SVG, MMD                                               |
| Sharing       | Editor link and SVG link where supported                    |
| Samples       | Start from sample diagrams                                  |
| Permissions   | Respect owner/editor/viewer access                          |
| States        | Loading, empty, error, no-results                           |
| Accessibility | Keyboard-accessible cards, rows, menus, search, and filters |

## 32. Recommended Advanced Scope

| Area              | Advanced Requirement                                           |
| ----------------- | -------------------------------------------------------------- |
| Workspace library | Team diagrams, personal diagrams, shared-with-me               |
| Smart filters     | Type, owner, date, comments, AI-generated, presentation-linked |
| Activity          | Recent activity, unresolved comments, last editor              |
| Presentations     | Deck library and diagram-to-deck workflows                     |
| AI                | Generate from Library, prompt history, AI-generated labels     |
| Bulk actions      | Multi-select, batch move/export/delete/share                   |
| Revision access   | Open timeline/version history from Library                     |
| Admin             | Workspace content management and audit-aware views             |
| Security          | External sharing visibility and SSO-backed access policies     |
| Offline/sync      | Local drafts, pending sync, reconnect reconciliation           |

## 33. Key Product Caveat

The Library should not be just a file picker. It should be the **workspace command center** for Mermaid content.

The ideal model is:

```text
Library
→ find the right diagram
→ understand its status
→ open it in the right mode
→ share/export/present it
→ organize it into a workspace
→ return later with history, permissions, and context intact
```

The most important design rule: **make Mermaid documents feel alive.** A Library item should communicate whether the diagram is editable, shared, commented on, presentation-linked, recently changed, AI-generated, or blocked by permissions.

[1]: https://mermaid.ai/docs/guides/whiteboard?utm_source=chatgpt.com "Mermaid Chart - Create complex, visual diagrams with text. A smarter way of creating diagrams."
