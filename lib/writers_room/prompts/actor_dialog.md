---
description: User prompt for generating character dialog
parameters:
  character_name: null
  conversation_history: null
  additional_context: null
---
## Conversation So Far

<% if conversation_history.empty? %>
(Scene just started -- you may initiate conversation if appropriate)
<% else %>
<% conversation_history.last(10).each do |exchange| %>
<%= exchange[:speaker] %>: <%= exchange[:line] %>
<% end %>
<% end %>

<% if additional_context %>
## Additional Context

<%= additional_context %>
<% end %>

What does <%= character_name %> say?
