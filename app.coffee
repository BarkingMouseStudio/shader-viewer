### REQUIRES ###
connect = require 'connect'
compiler = require './lib/compiler'
fs = require 'fs'
http = require 'http'
io = require 'socket.io'
path = require 'path'
prompt = require 'prompt'
watch = require 'watch'
_ = require 'underscore'


### CONSTANTS ###
ASSET_FOLDERS = [
  'fragments',
  'textures',
  'models',
  'vertices'
]


### HELPER FUNCTIONS ###
parseArgs = (args) ->
  args = args[2..]
  options = {}
  i = 0
  while i < args.length
    options[args[i++]] = args[i++]
  return options


### OPTIONS ###
options = parseArgs(process.argv)
directory = path.resolve(process.cwd(), options['--dir'])
port = options['--port'] or 3000


### SETUP SERVER ###
app = connect()
app.use(compiler(src: "#{__dirname}/src", dest: "#{__dirname}/public", enable: ['coffeescript', 'less'])) # looks for coffee and sass files to compile
app.use(connect.logger(format: '[:date] [:response-time] [:status] [:method] [:url]'))
app.use(connect.bodyParser()) # pre-parses JSON body responses
app.use(connect.static("#{__dirname}/public"))
app.use(connect.static(directory))

server = http.createServer(app)
server.listen port, ->
  console.log "Server at http://localhost:#{port}"


### START MONITORING ###
io = io.listen(server)
io.set('log level', 1)

singularize = (str) -> str.replace(/s$/, '')

# Read a file and send it's contents to the client
emitFile = (socket, event, file) ->
  name = path.basename(file)
  group = path.basename(path.dirname(file))

  unless group in ASSET_FOLDERS
    return

  socket.emit "file:#{event}", {
    id: name.replace(/\W/g, '_'),
    name: name.replace /\W(\w)/g, ($0, $1) ->
      $1.toUpperCase()
    path: "#{group}/#{name}",
    title: name,
    group: group,
    type: singularize(group)
  }

# Loop through existing files and send to the client
emitFiles = (socket, folder) ->
  fs.readdir "#{directory}/#{folder}", (err, files) ->
    if err
      console.error(err.message)
      return

    unless files
      return

    # Send the full path "#{directory}/#{folder}/#{file}"
    for file in files
      if /^\./.test(file)
        continue
      emitFile(socket, 'created', "#{directory}/#{folder}/#{file}")

io.sockets.on 'connection', (socket) ->
  # Loop through the folders because readdir isn't recursive
  emitFiles(socket, folder) for folder in ASSET_FOLDERS
  
  # Monitor for new files and changes to existing files
  watch.createMonitor directory, {
    persistent: true,
    interval: 500
  }, (monitor) ->
    monitor.on 'created', (f, stat) ->
      console.log "created #{f}"
      emitFile(socket, 'created', f)
    monitor.on 'changed', (f, curr, prev) ->
      console.log "changed #{f}"
      emitFile(socket, 'changed', f)
    monitor.on 'removed', (f, stat) ->
      console.log "removed #{f}"
      emitFile(socket, 'removed', f)


### CREATE ASSET_FOLDERS ###
fs.readdir directory, (err, files) ->
  if err
    console.error(err.message)
    return

  # Return if we are not missing any folders
  if _.intersection(ASSET_FOLDERS, files).length is ASSET_FOLDERS.length
    return

  # Ask if we want to add missing folders
  prompt.message = 'Question'
  prompt.start()

  question =
    name: 'create_folders'
    message: 'Auto-create required sub-folders? Y/n'
    validator: /y(es)?|n(o)?/
    warning: "Really? It's just a yes or no question..."
    default: 'no'

  # Make any directories that don't exist
  prompt.get question, (err, result) ->
    unless result.create_folders is 'yes'
      return

    for type in ASSET_FOLDERS
      fs.mkdir "#{directory}/#{type}" unless _.contains(files, type)
