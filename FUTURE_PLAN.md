# Future Improvements Plan

As we scale this platform, the biggest challenge isn't just handling more data—it’s making that data smarter and more actionable. By moving away from raw, unmanageable text blocks toward a structured **RAG architecture** and a proactive **command-driven chat**, we can drastically reduce latency and operational costs.

This approach doesn't just solve the technical "context window" problem; it transforms the product into a centralized command center where scheduling, CRM updates, and bot management happen seamlessly within a single conversation.

---

## 1. The Core Shift: From "Raw Text" to RAG

Right now, we are hitting a classic scalability wall: sending the entire meeting transcript to Gemini for every single query. That works for a prototype, but in production, we are going to run into "Context Window Exceeded" errors, massive token costs, and sluggish response times.

The fix is moving to **Retrieval-Augmented Generation (RAG)**. We need to stop asking the AI to "read the whole book" every time and instead hand it only the relevant pages.

### A. Vector Embeddings (Building "Long-Term Memory")

We need to change how we store transcripts. Storing them just as text strings isn't enough; we need to turn that text into numbers (vectors) that represent meaning.

**The Implementation Plan:**

* **Chunking:** Break the transcripts into smaller, bite-sized pieces (around 500 tokens is usually the sweet spot).
* **Embeddings:** Run those chunks through an embedding model (like Gemini’s `text-embedding-004` or an open-source equivalent). This converts the text into a vector list.
* **Storage (Keep it Simple):** Since we are already on Elixir and Postgres, use **pgvector**. We don't need to spin up a new infrastructure beast like Pinecone. `pgvector` keeps the embeddings right alongside the business data, maintaining ACID compliance and simplifying our stack.

**How Retrieval Works:** When a user asks, *"What did the client say about the budget?"*, we convert that question into a vector. We then perform a cosine similarity search in Postgres to find the specific chunks of the meeting where "budget" was discussed. We send only those specific paragraphs to the LLM. It’s faster, cheaper, and more accurate.

### B. Hierarchical Summarization (The "Pyramid" Approach)

RAG is great for specific details, but it's overkill for general questions. If a user asks, *"How did the meeting go?"*, the AI shouldn't have to read 50 tiny chunks to figure that out. We need a data hierarchy.

**The Pipeline:**

* **Level 1 (The Raw Data):** Keep the full raw transcript for deep dives, but rarely query it directly.
* **Level 2 (The Summary):** The moment a meeting ends, trigger a background job. Have the AI generate a concise summary, a bulleted list of action items, and a sentiment check. Save these as structured fields in the DB.
* **Level 3 (The Entities):** Extract hard data points—People, Companies, Dates—and store them as JSON objects.

**The Benefit:** When a user asks a high-level question like *"What did we agree on last week?"*, the system doesn't touch the raw text. It queries the **Level 2 Summary**. This reduces the prompt size from 10,000 tokens to 200, making the system feel instant.

---

## 2. The Chat Interface: From "Q&A" to "Command Center"

Right now, the chat is great for asking questions about the past, but it should really be driving your future actions. The highest-value features we can add are the ones that save the user from context-switching between tabs.

### Scheduling Made Simple

A user shouldn’t have to leave the app to set up a follow-up. They should be able to just say:

> *"Schedule a sync with a Nabeel from Salesforce next Tuesday at 2 PM."*

**The Workflow:** 1. The system recognizes the intent via NLP.
2. It fetches the relevant contact data from Salesforce.
3. It checks connected calendars (Google/Outlook) for conflicts.
4. It creates the event and generates a meeting link.

**The Integration:** We can prompt the user to pick their provider—**Zoom** or **Google Meet**—and automatically generate the meeting link right there in the chat response.

### Bot Control

If a user types *"Disable recording for the internal all-hands,"* the system should parse that intent and toggle the backend flags for the Recall.ai bot immediately. It makes the bot feel like an active assistant rather than just a passive recorder.

