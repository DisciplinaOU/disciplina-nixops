## AWS

```sh
nix-shell --run aws-rotate-key
```

## Buildkite

At [Buildkite GraphQL Explorer](https://buildkite.com/user/graphql/console), run:

```graphql
query ListAgentTokens {
  organization(slug: "disciplina") {
    id
    agentTokens {
      edges {
        node {
          id
          token
	  revokedAt
        }
      }
    }
  }
}
```

That will list organization ID along with all tokens, whether revoked or not.
Find active tokens (`revokedAt` will be `null`) and revoke by token ID:

```graphql
mutation RevokeAgentToken {
  agentTokenRevoke(input: {
    id: "000000000000000000000000000000000000000000000000000000000000000000=="
  }) {
    agentToken {
      id
      description
      revokedAt
      revokedBy {
        name
      }
    }
  }
}
```

And finally, create a new token:

```graphql
mutation CreateAgentToken {
  agentTokenCreate(input: {
    organizationID: "T3JnYW5pemF0aW9uLS0tNmJiMDkyNTMtOTEzOS00YWQ0LWJmMGItMWFlMDY1MjhhNzMx",
    description: "Disciplina NixOps cluster"
  }) {
    agentTokenEdge {
      node {
        id
        description
        token
      }
    }
  }
}
```

## Disciplina

### Committee secret

```sh
cat /dev/urandom | head -c 32 | base64
```
