### SETUP ###
menu =
  vertexs: document.getElementById 'vertex-selection'
  fragments: document.getElementById 'fragment-selection'
  images: document.getElementById 'image-selection'
  models: document.getElementById 'model-selection'

uniforms =
  rand:
    type: 'f'
    value: Math.random()
  time:
    type: 'f'
    value: 1.0

vertexShader = vertexShader or null
fragmentShader = fragmentShader or null

### HELPER FUNCTIONS ###
purge = (el) ->
  for attribute in el.attributes
    el[attribute.name] = null if typeof el[attribute.name] is "function"            
  for child in el.childNodes
    purge child  
  return
      
# ### 3JS FUNCTIONS ###      
colorToVector3 = (color) ->
  return new THREE.Vector3(color.r, color.g, color.b)

# Renderer
renderer = new THREE.WebGLRenderer(antialias: true)
# renderer.setClearColorHex(0xffffff, 1)
renderer.setSize(width = window.innerWidth, height = window.innerHeight)
renderer.autoClear = false

# DOM
contentEl = document.getElementById('content')
contentEl.appendChild(renderer.domElement)
contentEl.onselectstart = -> false

# Scene
scene = new THREE.Scene()
scene.fog = new THREE.FogExp2(0x333333, 0.0025)
renderer.setClearColor(scene.fog.color, 1)

# Camera
viewAngle = 45
aspectRatio = width / height
camera = new THREE.PerspectiveCamera(viewAngle=45, aspectRatio, 1, 10000)
camera.position.z = 300
scene.add(camera)

# Controls
controls = new THREE.TrackballControls(camera)
controls.zoomSpeed = 0.05
controls.minDistance = 150
controls.maxDistance = 500

# Lights
ambientLight = new THREE.AmbientLight(0x222222)
scene.add(ambientLight)

pointLight = new THREE.PointLight(0xffffff, 1, 500)
pointLight.position.set(150, 150, 150)
scene.add(pointLight)

# Plane
planeMaterial = new THREE.MeshBasicMaterial(wireframe: true, color: 0x888888)
plane = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000, 40, 40), planeMaterial)
plane.rotation.x = 90
plane.position.y = -50
plane.rotation.z = Math.PI / 4
scene.add(plane)

# Sphere
# sphereMaterial = new THREE.ShaderMaterial
#   vertexShader: vertexShader
#   fragmentShader: fragmentShader
#   uniforms: uniforms
# sphere = new THREE.Mesh(new THREE.SphereGeometry(50, 32, 32), sphereMaterial)
# scene.add(sphere)

# Effects
renderTarget = new THREE.WebGLRenderTarget width, height, parameters =
  minFilter: THREE.LinearFilter
  magFilter: THREE.LinearFilter
  format: THREE.RGBAFormat

effectComposer = new THREE.EffectComposer(renderer, renderTarget)

modelPass = new THREE.RenderPass(scene, camera)

screenPass = new THREE.ShaderPass(THREE.ShaderExtras['screen'])
screenPass.renderToScreen = true

vignettePass = new THREE.ShaderPass(THREE.ShaderExtras['vignette'])
vignettePass.uniforms.offset.value = 0.2 # 0.4
vignettePass.uniforms.darkness.value = 6
vignettePass.renderToScreen = true

effectComposer.addPass(modelPass)
effectComposer.addPass(vignettePass)

# Render
render = ->
  controls.update()
  uniforms.time.value += 0.02
  uniforms.rand.value = Math.random()

  renderer.clear()
  effectComposer.render(0.1)

  requestAnimationFrame(render)

render()


### EVENTS ####
update = (res) ->
  console.log "update #{res.name}"
  # sphereMaterial.vertexShader = res.data
  # sphereMaterial.fragmentShader = res.data
  # sphereMaterial.needsUpdate = true

create = (res) ->
  console.log "created #{res.name}"
  name = document.createTextNode(res.name);

  el = document.createElement('a')
  el.setAttribute('href', "#{res.type}/#{res.name}")
  el.setAttribute('id', res.name.replace('.','_'))
  el.appendChild(name);
  
  parent = menu[res.type]
  parent.appendChild(el)
  

remove = (res) ->
  console.log "removed #{res.name}"
  el = document.getElementById(res.name.replace('.','_'))
  purge(el)
  el.parentNode.removeChild(el)
  
### SOCKET.IO ###
socket = io.connect()
socket.on 'file:created', (res) ->
  create res
socket.on 'file:changed', (res) ->
  update res
socket.on 'file:removed', (res) ->
  remove res
