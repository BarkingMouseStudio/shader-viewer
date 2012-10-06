express = require 'express'
_ = require 'underscore'
http = require 'http'
io = require 'socket.io'
fs = require 'fs'
path = require 'path'

parseArgs = (args) ->
  args = args[2..]
  options = {}
  i = 0
  while i < args.length
    options[args[i++]] = args[i++]
  return options

sendShader = (socket, filename, type) ->
  fs.readFile filename, (err, shaderBuffer) ->
    if err
      console.error 'ERROR', err.message
      return

    shader = shaderBuffer.toString()
    socket.emit 'shader', type, shader

watchShader = (filename, type) ->
  console.log "Watching #{type} shader at #{filename}..."

  fs.watchFile filename, {
    persistent: true,
    interval: 1000
  }, (curr, prev) ->
    if curr.mtime > prev.mtime
      sendShader(io.sockets, filename, type)

options = parseArgs(process.argv)

fragmentPath = path.resolve(process.cwd(), options['--fragment'])
vertexPath = path.resolve(process.cwd(), options['--vertex'])

unless path.existsSync(fragmentPath)
  console.warn "Fragment shader does not exist"
  return

unless path.existsSync(vertexPath)
  console.warn "Vertex shader does not exist"
  return

app = express()
app.use(express.static("#{__dirname}/public"))

server = http.createServer(app)
io = io.listen(server)
io.set('log level', 1)

server.listen(port=3000)

console.log "Server listening on #{port}..."

watchShader(fragmentPath, 'fragment')
watchShader(vertexPath, 'vertex')

sendShader(io.sockets, fragmentPath, 'fragment')
sendShader(io.sockets, vertexPath, 'vertex')

io.sockets.on 'connection', (socket) ->
  sendShader(socket, fragmentPath, 'fragment')
  sendShader(socket, vertexPath, 'vertex')
