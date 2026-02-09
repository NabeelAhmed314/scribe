# Technical Implementation Assumptions
The following architectural and design assumptions were made during the development of the Salesforce integrations to ensure consistency and maintainable code quality:

1. Unified Styling Framework
    - Assumption: Salesforce-related UI components, including the suggestion modals and settings pages, are styled exclusively using Tailwind CSS.

    - Rationale: This ensures that new CRM integrations remain visually consistent with the existing application design system without introducing custom CSS overhead.

2. Architectural Parity (CRM Patterning)
    - Assumption: The Salesforce implementation was designed to mirror the existing HubSpot integration patterns.

    - Rationale: By following the established HubSpot workflow for OAuth, token management, and data fetching, the codebase remains predictable. This "Base CRM" approach simplifies future maintenance and makes it easier to onboard additional CRM platforms.

3. Chat Mention Constraints
    - Assumption: In the Chat LiveView, a specific contact can be mentioned (@tagged) only once within a single query context.

    - Rationale: This constraint prevents duplicate data processing and keeps the UI clean during the asynchronous lookup and tagging process, ensuring the AI model receives a distinct list of entities to query.