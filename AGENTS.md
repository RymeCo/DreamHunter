## Atlassian Rovo MCP

When connected to atlassian-rovo-mcp:
- **MUST** use Jira project key = "SCRUM"
- **MUST** use cloudId = "https://ractenopen.atlassian.net" (do NOT call getAccessibleAtlassianResources)
- **MUST** use `maxResults: 10` or `limit: 10` for ALL Jira JQL and Confluence CQL search operations.
