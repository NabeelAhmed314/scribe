# Current System Limitations

## Technical Scalability & Performance

### Context Window Constraints

Currently, the system sends **raw, full-text transcripts** to Gemini for every query.

* **Impact:** As meeting lengths increase (e.g., workshops over 60 minutes), we risk hitting the LLM’s context window limit. This leads to truncated data, failed API calls, and a significant increase in latency as the model processes thousands of tokens of "noise" to find a single answer.

### Operational Costs

Because we are re-sending the entire transcript for every chat interaction, token consumption is inefficient.

* **Impact:** High recurring costs for LLM usage that scale linearly with transcript length, regardless of the complexity of the user's question.

---

## Data Intelligence & Accuracy

### Lack of Speaker Diarization

The current integration with the bot service provides a flat text transcript without identifying who is speaking or assigning subjects to specific participants.

* **Impact:** The AI cannot reliably distinguish between "What the client said" and "What the sales rep promised." This makes automated CRM updates risky and requires manual verification for every suggestion.

### Linear Data Storage

Transcripts are stored as simple text blobs rather than structured, searchable entities.

* **Impact:** The system lacks "Long-Term Memory." It cannot efficiently perform cross-meeting analysis (e.g., *"Summarize everything we've discussed with Salesforce over the last three meetings"*) without fetching and processing multiple massive text files.

---

## Integration & Workflow Gaps

### Unidirectional CRM Flow

The current Salesforce and HubSpot integrations are primarily designed for viewing and suggesting updates rather than deep, two-way synchronization.

* **Impact:** Users still have to jump between the chat and their CRM for complex tasks. The system lacks a "write" capability driven by structured function calling, making it more of an observer than an active participant.

### Passive Bot Management

The recording bot is currently managed through a simple toggle or settings page rather than being integrated into the active workspace.

* **Impact:** Users cannot control the bot's behavior (e.g., pausing, stopping, or joining) in real-time through the chat interface, leading to friction in sensitive or unplanned meeting moments.



