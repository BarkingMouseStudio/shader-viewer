### SETUP ###
menu =
  vertices: document.getElementById 'vertex-selection'
  fragments: document.getElementById 'fragment-selection'
  textures: document.getElementById 'texture-selection'
  models: document.getElementById 'model-selection'

assets = {}

defaultVertex = document.getElementById('default-vertex-shader').innerHTML
defaultFragment = document.getElementById('default-fragment-shader').innerHTML


### HELPER FUNCTIONS ###
purge = (el) ->
  unless el?.attributes
    return
  for attribute in el.attributes
    if typeof el[attribute.name] is 'function'
      el[attribute.name] = null 
  for child in el.childNodes
    purge(child)
  return


### RENDERER ###
renderer = new THREE.WebGLRenderer(antialias: true)
renderer.setSize(width = (window.innerWidth * .8), height = window.innerHeight)
renderer.autoClear = false
renderer.setClearColor(0x686d76, 1)


### DOM ###
contentEl = document.getElementById('content')
contentEl.appendChild(renderer.domElement)
contentEl.onselectstart = -> false


### SCENE ###
scene = new THREE.Scene()


### CAMERA ###
viewAngle = 45
aspectRatio = width / height
camera = new THREE.PerspectiveCamera(viewAngle=45, aspectRatio, 1, 10000)
camera.position.z = 200
scene.add(camera)


### CONTROLS ###
controls = new THREE.TrackballControls(camera)
controls.zoomSpeed = 0.05
controls.minDistance = 150
controls.maxDistance = 500


### LIGHTS ###
ambientLight = new THREE.AmbientLight(0x2c2f34)
scene.add(ambientLight)

pointLight1 = new THREE.PointLight(0xcce6ff, 1, 600)
pointLight1.position.set(-400, 300, 200)
scene.add(pointLight1)

pointLight2 = new THREE.PointLight(0xffffff, 1, 800)
pointLight2.position.set(400, 300, 200)
scene.add(pointLight2)

pointLight3 = new THREE.PointLight(0xffddcc, 1, 1000)
pointLight3.position.set(0, 300, 400)
scene.add(pointLight3)

uniforms = {
  ambientLightColor: {
    type: 'v3',
    value: ambientLight.color
  },
  pointLightColor: {
    type: 'fv3',
    value: [
      pointLight1.color,
      pointLight2.color,
      pointLight3.color
    ]
  },
  pointLightPosition: {
    type: 'fv3',
    value: [
      pointLight1.position,
      pointLight2.position,
      pointLight3.position
    ]
  },
  pointLightDistance: {
    type: 'fv1',
    value: [
      pointLight1.distance,
      pointLight2.distance,
      pointLight3.distance
    ]
  },
  rand: {
    type: 'f',
    value: Math.random()
  },
  time: {
    type: 'f',
    value: 1.0
  }
}


console.warn uniforms

### PLANE ###
loader = new THREE.GeometryLoader()
loader.load('../assets/backdrop.js')
loader.addEventListener 'load', (res) ->
  { content: backdropGeometry } = res
  backdropMaterial = new THREE.MeshLambertMaterial({
    map: THREE.ImageUtils.loadTexture('../assets/backdrop.jpg')
  })
  backdropMesh = new THREE.Mesh(backdropGeometry, backdropMaterial)
  backdropMesh.scale.set(20, 20, 20)
  backdropMesh.rotation.set(0, -Math.PI / 2, 0)
  backdropMesh.position.set(0, -50, -150)
  scene.add(backdropMesh)


### SPHERE ###
modelMaterial = new THREE.ShaderMaterial
  vertexShader: defaultVertex
  fragmentShader: defaultFragment
  uniforms: uniforms

sphere = new THREE.Mesh(new THREE.SphereGeometry(50, 32, 32), modelMaterial)
scene.add(sphere)


### EFFECTS ###
renderTarget = new THREE.WebGLRenderTarget width, height, parameters =
  minFilter: THREE.LinearFilter
  magFilter: THREE.LinearFilter
  format: THREE.RGBAFormat

effectComposer = new THREE.EffectComposer(renderer, renderTarget)

modelPass = new THREE.RenderPass(scene, camera)

vignettePass = new THREE.ShaderPass(THREE.CopyShader)
vignettePass.renderToScreen = true

effectComposer.addPass(modelPass)
effectComposer.addPass(vignettePass)


### RENDER ###
render = ->
  controls.update()
  uniforms.time.value += 0.02
  uniforms.rand.value = Math.random()

  renderer.clear()
  effectComposer.render(0.1)

  requestAnimationFrame(render)

render()


### ASSETS ###
loadError = (message) ->
  console.error 'Unable to load asset:', message

assetLoaded = (res, asset) ->
  assets[res.id] = asset
  modelMaterial.needsUpdate = true
  el = document.getElementById(res.id)
  el.className = 'active'

loadAsset = (res) ->
  switch res.type
    when 'texture'
      THREE.ImageUtils.loadTexture res.path, null, (texture) ->
        uniforms[res.id] = {
          type: 't',
          value: texture
        }
        assetLoaded(res, texture)
      , loadError
    when 'fragment', 'vertice'
      req = new XMLHttpRequest()
      req.open('GET', res.path, true)
      req.addEventListener 'load', (e) ->
        shader = req.responseText
        switch res.type
          when 'vertice'
            modelMaterial.vertexShader = shader
          when 'fragment'
            modelMaterial.fragmentShader = shader
        assetLoaded(res, shader)
      , false
      req.addEventListener 'error', loadError, false
      req.send()
    when 'model'
      emitter = THREE.GeometryLoader.load(res.path)
      emitter.addEventListener 'load', (geometry) ->
        assetLoaded(res, geometry)
      emitter.addEventListener('error', loadError)


### EVENTS ####
update = (res) ->
  loadAsset(res)

create = (res) ->
  title = document.createTextNode(res.title)

  el = document.createElement('a')
  el.setAttribute('href', '#')
  el.setAttribute('id', res.id)
  el.appendChild(title)

  el.addEventListener 'click', (e) ->
    e.preventDefault()
    loadAsset(res) unless assets[res.id]
  
  parent = menu[res.group]
  parent.appendChild(el)

remove = (res) ->
  el = document.getElementById(res.id)
  purge(el)
  el.parentNode.removeChild(el)
  delete assets[res.id]
  switch res.type
    when 'texture'
      delete uniforms[res.id]
    when 'fragment'
      modelMaterial.fragmentShader = defaultFragment
    when 'vertice'
      modelMaterial.vertexShader = defaultVertex

  
### SOCKET.IO ###
socket = io.connect()
socket.on 'file:created', (res) ->
  create res
socket.on 'file:changed', (res) ->
  update res
socket.on 'file:removed', (res) ->
  remove res
