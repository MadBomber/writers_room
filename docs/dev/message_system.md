# Message System

WritersRoom uses TypedBus for inter-actor communication and RobotLab shared memory for persistent state.

## Bus Channels

Each Room creates a `TypedBus::MessageBus` with a single `:scene` channel. All actors in the scene subscribe to this channel.

Messages on the `:scene` channel are plain hashes:

```ruby
{
  from: "Alice",
  type: :dialog,
  content: "Hi Bob, how are you?",
  emotion: "friendly"
}
```

## Tools as the Communication Layer

Actors do not send messages directly. Instead, the LLM calls tools that handle communication:

### SpeakTool

The primary communication mechanism. When the LLM wants a character to speak, it calls the `speak` tool with `dialog` and optional `emotion` parameters. The tool:

1. Appends the dialog entry to `:dialog_history` in shared memory
2. Broadcasts the message to the `:scene` bus channel
3. Updates the Display with formatted output

### MarkSceneCompleteTool

Sets `:scene_complete` in shared memory, signaling the Room to stop the scene.

### ReadMemoryTool / WriteMemoryTool / ListMemoryTool

Allow actors to read and write arbitrary state in shared memory. Useful for tracking scene context, character observations, and narrative notes.

### ReadFileTool / WriteFileTool / ListDirectoryTool

File system tools that allow actors to read from and write to project files, and list directory contents. Useful for actors that need to reference project materials during a scene.

### ProjectTool

Provides access to project metadata and configuration, allowing actors to be aware of the project context.

## Shared Memory

`RobotLab::Memory` provides a reactive key-value store shared by all actors in a Room.

Key conventions:

| Key | Type | Purpose |
|-----|------|---------|
| `:dialog_history` | Array of Hashes | Ordered list of all spoken dialog |
| `:scene_complete` | Boolean | Signals scene completion |
| `:line_count` | Integer | Current dialog line count |

Actors can also write custom keys for their own observations and notes.

## Message Flow

1. Room calls `seed` with an opening prompt directed at the first actor
2. The actor's LLM processes the prompt and calls `SpeakTool`
3. `SpeakTool` records the dialog in shared memory and broadcasts to `:scene`
4. Other actors receive the broadcast via their bus subscription
5. Each receiving actor calls `fresh_chat!` (resetting chat context), then `run` with the incoming message
6. The cycle continues until `max_lines` is reached or `MarkSceneCompleteTool` is called
7. Room's `wait_for_completion` detects the stop condition and returns control to the Director

## Heartbeat

During `wait_for_completion`, the Room periodically sends heartbeat messages to keep the conversation flowing if actors go quiet. This prevents stalls without requiring a sleep-polling loop.
