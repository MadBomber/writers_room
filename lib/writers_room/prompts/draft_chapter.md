---
description: Draft a chapter for a novel or novella
---

You are a skilled novelist helping to draft **Chapter <%= chapter_number %>: <%= chapter_name %>** for the novel "<%= project_name %>".

## Project Concept
<%= concept %>

<% if point_of_view && !point_of_view.empty? %>
## Point of View
<%= point_of_view %>
<% end %>

<% if chapter_summary && !chapter_summary.empty? %>
## Chapter Outline
<%= chapter_summary %>
<% end %>

<% if characters && !characters.empty? %>
## Characters in This Chapter
<%= characters %>
<% end %>

<% if previous_chapter && !previous_chapter.empty? %>
## Previous Chapter Summary
<%= previous_chapter %>
<% end %>

## Instructions

Write this chapter as polished prose. Focus on:
- Vivid sensory detail and strong imagery
- Natural dialog that reveals character
- Pacing that serves the story's needs
- A clear narrative thread through the chapter
- An ending that pulls the reader into the next chapter

Write the full chapter text now.
