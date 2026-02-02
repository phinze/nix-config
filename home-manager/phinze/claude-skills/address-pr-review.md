# Address PR Review Feedback

Help me work through PR review comments and decide what to fix vs skip.

## Steps

1. **Download the review**: Run `pr-review-download` to fetch all review comments

2. **Categorize the feedback**:
   - **Human comments**: Treat ALL of these as important - humans took time to write them
   - **CodeRabbit actionable**: Real issues worth addressing
   - **CodeRabbit nitpicks**: Style/preference stuff - we'll decide case by case

3. **Create a plan** with two sections:

   **Will Address**:
   - List each item we're going to fix
   - Brief note on the approach

   **Will Skip** (with draft responses):
   - For nitpicks: fine to skip silently
   - For non-nitpick items we're skipping: draft a polite response explaining why
     (e.g., "Good point, but keeping it simple for now" or "Intentional - here's why...")

4. **Show me the plan** and wait for approval before making changes

5. **After approval**: Work through the fixes, then help draft/post any responses

## Response Style
- Responses should be concise and friendly
- Acknowledge the reviewer's point even when disagreeing
- Use "we" language (collective ownership)

## Example Plan Format

```
## Will Address

1. **@reviewer: "Should handle the nil case here"**
   → Add nil check before accessing the field

2. **CodeRabbit: Missing error handling in fetchData**
   → Wrap in try/catch and surface error to user

## Will Skip

1. **CodeRabbit (nitpick): Consider using const instead of let**
   → Skipping (style preference)

2. **CodeRabbit: Could extract this to a helper function**
   → Draft response: "Keeping it inline for now since it's only used once.
      Happy to extract if we end up needing it elsewhere."

Ready to proceed?
```
