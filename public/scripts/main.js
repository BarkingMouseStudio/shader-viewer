
/* SETUP
*/


(function() {
  var activeFragment, activeVertex, ambientLight, aspectRatio, camera, colorToVector3, contentEl, controls, create, defaultFragment, defaultVertex, effectComposer, fragment, getShaders, height, menu, modelPass, parameters, plane, planeMaterial, pointLight, purge, remove, render, renderTarget, renderer, scene, screenPass, socket, sphere, sphereMaterial, uniforms, update, vertex, viewAngle, vignettePass, width, _ref;

  menu = {
    vertexs: document.getElementById('vertex-selection'),
    fragments: document.getElementById('fragment-selection'),
    images: document.getElementById('image-selection'),
    models: document.getElementById('model-selection')
  };

  uniforms = {
    rand: {
      type: 'f',
      value: Math.random()
    },
    time: {
      type: 'f',
      value: 1.0
    }
  };

  activeVertex = activeFragment = null;

  defaultVertex = document.getElementById('default-vertex-shader').innerHTML;

  defaultFragment = document.getElementById('default-fragment-shader').innerHTML;

  /* HELPER FUNCTIONS
  */


  purge = function(el) {
    var attribute, child, _i, _j, _len, _len1, _ref, _ref1;
    _ref = el.attributes;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      attribute = _ref[_i];
      if (typeof el[attribute.name] === "function") {
        el[attribute.name] = null;
      }
    }
    _ref1 = el.childNodes;
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      child = _ref1[_j];
      purge(child);
    }
  };

  getShaders = function() {
    var fragment, vertex;
    if (!activeFragment) {
      fragment = defaultFragment;
    }
    if (!activeVertex) {
      vertex = defaultVertex;
    }
    return [fragment, vertex];
  };

  _ref = getShaders(), fragment = _ref[0], vertex = _ref[1];

  colorToVector3 = function(color) {
    return new THREE.Vector3(color.r, color.g, color.b);
  };

  renderer = new THREE.WebGLRenderer({
    antialias: true
  });

  renderer.setSize(width = window.innerWidth * .8, height = window.innerHeight);

  renderer.autoClear = false;

  contentEl = document.getElementById('content');

  contentEl.appendChild(renderer.domElement);

  contentEl.onselectstart = function() {
    return false;
  };

  scene = new THREE.Scene();

  scene.fog = new THREE.FogExp2(0x333333, 0.0025);

  renderer.setClearColor(scene.fog.color, 1);

  viewAngle = 45;

  aspectRatio = width / height;

  camera = new THREE.PerspectiveCamera(viewAngle = 45, aspectRatio, 1, 10000);

  camera.position.z = 300;

  scene.add(camera);

  controls = new THREE.TrackballControls(camera);

  controls.zoomSpeed = 0.05;

  controls.minDistance = 150;

  controls.maxDistance = 500;

  ambientLight = new THREE.AmbientLight(0x222222);

  scene.add(ambientLight);

  pointLight = new THREE.PointLight(0xffffff, 1, 500);

  pointLight.position.set(150, 150, 150);

  scene.add(pointLight);

  planeMaterial = new THREE.MeshBasicMaterial({
    wireframe: true,
    color: 0x888888
  });

  plane = new THREE.Mesh(new THREE.PlaneGeometry(2000, 2000, 40, 40), planeMaterial);

  plane.rotation.x = 90;

  plane.position.y = -50;

  plane.rotation.z = Math.PI / 4;

  scene.add(plane);

  sphereMaterial = new THREE.ShaderMaterial({
    vertexShader: vertex,
    fragmentShader: fragment,
    uniforms: uniforms
  });

  sphere = new THREE.Mesh(new THREE.SphereGeometry(50, 32, 32), sphereMaterial);

  scene.add(sphere);

  renderTarget = new THREE.WebGLRenderTarget(width, height, parameters = {
    minFilter: THREE.LinearFilter,
    magFilter: THREE.LinearFilter,
    format: THREE.RGBAFormat
  });

  effectComposer = new THREE.EffectComposer(renderer, renderTarget);

  modelPass = new THREE.RenderPass(scene, camera);

  screenPass = new THREE.ShaderPass(THREE.ShaderExtras['screen']);

  screenPass.renderToScreen = true;

  vignettePass = new THREE.ShaderPass(THREE.ShaderExtras['vignette']);

  vignettePass.uniforms.offset.value = 0.2;

  vignettePass.uniforms.darkness.value = 6;

  vignettePass.renderToScreen = true;

  effectComposer.addPass(modelPass);

  effectComposer.addPass(vignettePass);

  render = function() {
    controls.update();
    uniforms.time.value += 0.02;
    uniforms.rand.value = Math.random();
    renderer.clear();
    effectComposer.render(0.1);
    return requestAnimationFrame(render);
  };

  render();

  /* EVENTS
  */


  update = function(res) {
    return console.log("update " + res.name);
  };

  create = function(res) {
    var el, name, parent;
    console.log("created " + res.name);
    name = document.createTextNode(res.name);
    el = document.createElement('a');
    el.setAttribute('href', "" + res.type + "/" + res.name);
    el.setAttribute('id', res.name.replace('.', '_'));
    el.appendChild(name);
    parent = menu[res.type];
    return parent.appendChild(el);
  };

  remove = function(res) {
    var el;
    console.log("removed " + res.name);
    el = document.getElementById(res.name.replace('.', '_'));
    purge(el);
    return el.parentNode.removeChild(el);
  };

  /* SOCKET.IO
  */


  socket = io.connect();

  socket.on('file:created', function(res) {
    return create(res);
  });

  socket.on('file:changed', function(res) {
    return update(res);
  });

  socket.on('file:removed', function(res) {
    return remove(res);
  });

}).call(this);
