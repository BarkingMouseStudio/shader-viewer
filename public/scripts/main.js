
/* SETUP
*/


(function() {
  var ambientLight, aspectRatio, assetLoaded, assets, camera, contentEl, controls, create, defaultFragment, defaultVertex, effectComposer, height, loadAsset, loadError, loader, menu, modelMaterial, modelPass, parameters, pointLight1, pointLight2, pointLight3, purge, remove, render, renderTarget, renderer, scene, socket, sphere, uniforms, update, viewAngle, vignettePass, width;

  menu = {
    vertices: document.getElementById('vertex-selection'),
    fragments: document.getElementById('fragment-selection'),
    textures: document.getElementById('texture-selection'),
    models: document.getElementById('model-selection')
  };

  assets = {};

  defaultVertex = document.getElementById('default-vertex-shader').innerHTML;

  defaultFragment = document.getElementById('default-fragment-shader').innerHTML;

  /* HELPER FUNCTIONS
  */


  purge = function(el) {
    var attribute, child, _i, _j, _len, _len1, _ref, _ref1;
    if (!(el != null ? el.attributes : void 0)) {
      return;
    }
    _ref = el.attributes;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      attribute = _ref[_i];
      if (typeof el[attribute.name] === 'function') {
        el[attribute.name] = null;
      }
    }
    _ref1 = el.childNodes;
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      child = _ref1[_j];
      purge(child);
    }
  };

  /* RENDERER
  */


  renderer = new THREE.WebGLRenderer({
    antialias: true
  });

  renderer.setSize(width = window.innerWidth * .8, height = window.innerHeight);

  renderer.autoClear = false;

  renderer.setClearColor(0x686d76, 1);

  /* DOM
  */


  contentEl = document.getElementById('content');

  contentEl.appendChild(renderer.domElement);

  contentEl.onselectstart = function() {
    return false;
  };

  /* SCENE
  */


  scene = new THREE.Scene();

  /* CAMERA
  */


  viewAngle = 45;

  aspectRatio = width / height;

  camera = new THREE.PerspectiveCamera(viewAngle = 45, aspectRatio, 1, 10000);

  camera.position.z = 200;

  scene.add(camera);

  /* CONTROLS
  */


  controls = new THREE.TrackballControls(camera);

  controls.zoomSpeed = 0.05;

  controls.minDistance = 150;

  controls.maxDistance = 500;

  /* LIGHTS
  */


  ambientLight = new THREE.AmbientLight(0x2c2f34);

  scene.add(ambientLight);

  pointLight1 = new THREE.PointLight(0xcce6ff, 1, 600);

  pointLight1.position.set(-400, 300, 200);

  scene.add(pointLight1);

  pointLight2 = new THREE.PointLight(0xffffff, 1, 800);

  pointLight2.position.set(400, 300, 200);

  scene.add(pointLight2);

  pointLight3 = new THREE.PointLight(0xffddcc, 1, 1000);

  pointLight3.position.set(0, 300, 400);

  scene.add(pointLight3);

  uniforms = {
    ambientLightColor: {
      type: 'v3',
      value: ambientLight.color
    },
    pointLightColor: {
      type: 'fv3',
      value: [pointLight1.color, pointLight2.color, pointLight3.color]
    },
    pointLightPosition: {
      type: 'fv3',
      value: [pointLight1.position, pointLight2.position, pointLight3.position]
    },
    pointLightDistance: {
      type: 'fv1',
      value: [pointLight1.distance, pointLight2.distance, pointLight3.distance]
    },
    rand: {
      type: 'f',
      value: Math.random()
    },
    time: {
      type: 'f',
      value: 1.0
    }
  };

  console.warn(uniforms);

  /* PLANE
  */


  loader = new THREE.GeometryLoader();

  loader.load('../assets/backdrop.js');

  loader.addEventListener('load', function(res) {
    var backdropGeometry, backdropMaterial, backdropMesh;
    backdropGeometry = res.content;
    backdropMaterial = new THREE.MeshLambertMaterial({
      map: THREE.ImageUtils.loadTexture('../assets/backdrop.jpg')
    });
    backdropMesh = new THREE.Mesh(backdropGeometry, backdropMaterial);
    backdropMesh.scale.set(20, 20, 20);
    backdropMesh.rotation.set(0, -Math.PI / 2, 0);
    backdropMesh.position.set(0, -50, -150);
    return scene.add(backdropMesh);
  });

  /* SPHERE
  */


  modelMaterial = new THREE.ShaderMaterial({
    vertexShader: defaultVertex,
    fragmentShader: defaultFragment,
    uniforms: uniforms
  });

  sphere = new THREE.Mesh(new THREE.SphereGeometry(50, 32, 32), modelMaterial);

  scene.add(sphere);

  /* EFFECTS
  */


  renderTarget = new THREE.WebGLRenderTarget(width, height, parameters = {
    minFilter: THREE.LinearFilter,
    magFilter: THREE.LinearFilter,
    format: THREE.RGBAFormat
  });

  effectComposer = new THREE.EffectComposer(renderer, renderTarget);

  modelPass = new THREE.RenderPass(scene, camera);

  vignettePass = new THREE.ShaderPass(THREE.CopyShader);

  vignettePass.renderToScreen = true;

  effectComposer.addPass(modelPass);

  effectComposer.addPass(vignettePass);

  /* RENDER
  */


  render = function() {
    controls.update();
    uniforms.time.value += 0.02;
    uniforms.rand.value = Math.random();
    renderer.clear();
    effectComposer.render(0.1);
    return requestAnimationFrame(render);
  };

  render();

  /* ASSETS
  */


  loadError = function(message) {
    return console.error('Unable to load asset:', message);
  };

  assetLoaded = function(res, asset) {
    var el;
    assets[res.id] = asset;
    modelMaterial.needsUpdate = true;
    el = document.getElementById(res.id);
    return el.className = 'active';
  };

  loadAsset = function(res) {
    var emitter, req;
    switch (res.type) {
      case 'texture':
        return THREE.ImageUtils.loadTexture(res.path, null, function(texture) {
          uniforms[res.id] = {
            type: 't',
            value: texture
          };
          return assetLoaded(res, texture);
        }, loadError);
      case 'fragment':
      case 'vertice':
        req = new XMLHttpRequest();
        req.open('GET', res.path, true);
        req.addEventListener('load', function(e) {
          var shader;
          shader = req.responseText;
          switch (res.type) {
            case 'vertice':
              modelMaterial.vertexShader = shader;
              break;
            case 'fragment':
              modelMaterial.fragmentShader = shader;
          }
          return assetLoaded(res, shader);
        }, false);
        req.addEventListener('error', loadError, false);
        return req.send();
      case 'model':
        emitter = THREE.GeometryLoader.load(res.path);
        emitter.addEventListener('load', function(geometry) {
          return assetLoaded(res, geometry);
        });
        return emitter.addEventListener('error', loadError);
    }
  };

  /* EVENTS
  */


  update = function(res) {
    return loadAsset(res);
  };

  create = function(res) {
    var el, parent, title;
    title = document.createTextNode(res.title);
    el = document.createElement('a');
    el.setAttribute('href', '#');
    el.setAttribute('id', res.id);
    el.appendChild(title);
    el.addEventListener('click', function(e) {
      e.preventDefault();
      if (!assets[res.id]) {
        return loadAsset(res);
      }
    });
    parent = menu[res.group];
    return parent.appendChild(el);
  };

  remove = function(res) {
    var el;
    el = document.getElementById(res.id);
    purge(el);
    el.parentNode.removeChild(el);
    delete assets[res.id];
    switch (res.type) {
      case 'texture':
        return delete uniforms[res.id];
      case 'fragment':
        return modelMaterial.fragmentShader = defaultFragment;
      case 'vertice':
        return modelMaterial.vertexShader = defaultVertex;
    }
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
