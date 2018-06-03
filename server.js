const express = require('express')
const { postgraphql } = require('postgraphql')
const PostGraphileConnectionFilterPlugin = require('postgraphile-plugin-connection-filter')

const { user, password } = require('./creditional.json')

const app = express()
console.log(process.env.NODE_ENV)
const host = 'localhost'
const port = 5432
console.log('host: ', host)
const PORT = 4000

const pgql_config = {
  user,
  password,
  host,
  port,
  database: 'linkhub'
}

const pgql_schemas = ['main']

const pgql_options = {
  graphiql: true,
  pgDefaultRole: 'anonymous',
  jwtSecret: 'r3QkeL2OwKIPJxwZ',
  jwtPgTypeIdentifier: 'main.jwt_token',
  appendPlugins: [PostGraphileConnectionFilterPlugin],
  enableCors: true
}

app.use(postgraphql(pgql_config, pgql_schemas, pgql_options))

app.listen(PORT, () =>
  console.log(`GraphQL Server is now running on http://localhost:${PORT}`)
)
