import * as THREE from 'three'

// ---------- palette (Keepsake concept) ----------
const PAPER = 0xfbf7f2
const INK = 0x221d16
const INDIGO = 0x3b2e8c
const LAVENDER = 0xc9c0ff
const WARM = 0xf3efe6

// ---------- canvas helpers ----------
function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.arcTo(x + w, y, x + w, y + h, r)
  ctx.arcTo(x + w, y + h, x, y + h, r)
  ctx.arcTo(x, y + h, x, y, r)
  ctx.arcTo(x, y, x + w, y, r)
  ctx.closePath()
}

function makeLabelSprite(lines, { scale = 1, dark = false } = {}) {
  const pad = 40
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')
  const font1 = '700 64px Inter, system-ui, sans-serif'
  const font2 = '400 38px Inter, system-ui, sans-serif'
  ctx.font = font1
  const w1 = ctx.measureText(lines[0]).width
  ctx.font = font2
  const w2 = lines[1] ? ctx.measureText(lines[1]).width : 0
  canvas.width = Math.ceil(Math.max(w1, w2)) + pad * 2
  canvas.height = lines[1] ? 190 : 120
  const c2 = canvas.getContext('2d')
  // pill background
  c2.fillStyle = dark ? 'rgba(26,21,18,0.82)' : 'rgba(255,255,255,0.92)'
  roundRect(c2, 2, 2, canvas.width - 4, canvas.height - 4, 36)
  c2.fill()
  c2.strokeStyle = '#3B2E8C'
  c2.lineWidth = 3
  c2.stroke()
  c2.textAlign = 'center'
  c2.fillStyle = dark ? '#F5EEE4' : '#221D16'
  c2.font = font1
  c2.fillText(lines[0], canvas.width / 2, 82)
  if (lines[1]) {
    c2.font = font2
    c2.fillStyle = '#3B2E8C'
    c2.fillText(lines[1], canvas.width / 2, 146)
  }
  const tex = new THREE.CanvasTexture(canvas)
  tex.colorSpace = THREE.SRGBColorSpace
  const mat = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false })
  mat.name = `Label · ${lines[0]}`
  const sprite = new THREE.Sprite(mat)
  const h = 1.5 * scale
  sprite.scale.set((canvas.width / canvas.height) * h, h, 1)
  return sprite
}

// stylised "photo print": white border + warm abstract scene, like a memory print
function makePhotoCardTexture(hueA, hueB, motif) {
  const W = 512
  const H = 640
  const canvas = document.createElement('canvas')
  canvas.width = W
  canvas.height = H
  const ctx = canvas.getContext('2d')
  ctx.fillStyle = '#FFFFFF'
  ctx.fillRect(0, 0, W, H)
  const m = 28 // border
  const g = ctx.createLinearGradient(0, m, 0, H - m)
  g.addColorStop(0, hueA)
  g.addColorStop(1, hueB)
  ctx.fillStyle = g
  ctx.fillRect(m, m, W - 2 * m, H - 2 * m)
  const cx = W / 2
  if (motif === 'sunset') {
    ctx.fillStyle = 'rgba(255,244,214,0.95)'
    ctx.beginPath()
    ctx.arc(cx, 300, 70, 0, Math.PI * 2)
    ctx.fill()
    ctx.fillStyle = 'rgba(90,60,40,0.55)'
    ctx.beginPath()
    ctx.moveTo(m, 430)
    ctx.quadraticCurveTo(W * 0.3, 340, W * 0.55, 430)
    ctx.quadraticCurveTo(W * 0.75, 500, W - m, 440)
    ctx.lineTo(W - m, H - m)
    ctx.lineTo(m, H - m)
    ctx.closePath()
    ctx.fill()
  } else if (motif === 'friends') {
    ctx.fillStyle = 'rgba(40,30,60,0.65)'
    for (let i = 0; i < 4; i++) {
      const x = cx - 120 + i * 80
      ctx.beginPath()
      ctx.arc(x, 320, 26, 0, Math.PI * 2)
      ctx.fill()
      roundRect(ctx, x - 26, 350, 52, 90, 22)
      ctx.fill()
    }
    ctx.fillStyle = 'rgba(255,255,255,0.5)'
    ctx.beginPath()
    ctx.arc(W - 120, 140, 46, 0, Math.PI * 2)
    ctx.fill()
  } else if (motif === 'hills') {
    ctx.fillStyle = 'rgba(60,80,60,0.5)'
    ctx.beginPath()
    ctx.moveTo(m, 400)
    ctx.quadraticCurveTo(W * 0.35, 260, W * 0.6, 400)
    ctx.quadraticCurveTo(W * 0.8, 500, W - m, 420)
    ctx.lineTo(W - m, H - m)
    ctx.lineTo(m, H - m)
    ctx.closePath()
    ctx.fill()
    ctx.fillStyle = 'rgba(255,250,235,0.9)'
    ctx.beginPath()
    ctx.arc(140, 170, 42, 0, Math.PI * 2)
    ctx.fill()
  } else {
    // confetti / celebration
    for (let i = 0; i < 40; i++) {
      ctx.fillStyle = `hsla(${Math.floor(Math.random() * 360)},70%,70%,0.85)`
      ctx.beginPath()
      ctx.arc(m + Math.random() * (W - 2 * m), m + Math.random() * (H - 2 * m), 6 + Math.random() * 10, 0, Math.PI * 2)
      ctx.fill()
    }
  }
  const tex = new THREE.CanvasTexture(canvas)
  tex.colorSpace = THREE.SRGBColorSpace
  return tex
}

function makeGlowTexture(color = '#C9C0FF') {
  const S = 256
  const canvas = document.createElement('canvas')
  canvas.width = S
  canvas.height = S
  const ctx = canvas.getContext('2d')
  const g = ctx.createRadialGradient(S / 2, S / 2, 10, S / 2, S / 2, S / 2)
  g.addColorStop(0, color + 'EE')
  g.addColorStop(0.4, color + '66')
  g.addColorStop(1, color + '00')
  ctx.fillStyle = g
  ctx.fillRect(0, 0, S, S)
  const tex = new THREE.CanvasTexture(canvas)
  tex.colorSpace = THREE.SRGBColorSpace
  return tex
}

function makeDotTexture() {
  const S = 64
  const canvas = document.createElement('canvas')
  canvas.width = S
  canvas.height = S
  const ctx = canvas.getContext('2d')
  const g = ctx.createRadialGradient(S / 2, S / 2, 1, S / 2, S / 2, S / 2)
  g.addColorStop(0, 'rgba(59,46,140,0.9)')
  g.addColorStop(1, 'rgba(59,46,140,0)')
  ctx.fillStyle = g
  ctx.fillRect(0, 0, S, S)
  const tex = new THREE.CanvasTexture(canvas)
  tex.colorSpace = THREE.SRGBColorSpace
  return tex
}

// ---------- scene ----------
export function createScene({ asset }) {
  const scene = new THREE.Scene()
  scene.background = new THREE.Color(PAPER)
  scene.fog = new THREE.Fog(PAPER, 18, 60)

  const camera = new THREE.PerspectiveCamera(50, 9 / 16, 0.1, 120)
  camera.position.set(0, 0.6, 10)
  camera.lookAt(0, 0, -10)

  // ----- ring portals: AKCE 2009 -> CSE -> Sec A -----
  const ringDefs = [
    { id: 'ring-akce', label: ['AKCE 2009', 'College · 128 members'], z: -10, r: 5.0, color: INDIGO },
    { id: 'ring-cse', label: ['CSE', 'Department · 46 members'], z: -25, r: 4.2, color: 0x5a47b8 },
    { id: 'ring-seca', label: ['Sec A', 'Section · 22 members'], z: -40, r: 3.4, color: 0x8a76e8 },
  ]
  const ringsGroup = new THREE.Group()
  const ringMeshes = []
  ringDefs.forEach((def, i) => {
    const ring = new THREE.Group()
    const torusMat = new THREE.MeshBasicMaterial({ color: def.color })
    torusMat.name = `${def.label[0]} · Ring`
    const torus = new THREE.Mesh(new THREE.TorusGeometry(def.r, 0.16, 24, 128), torusMat)
    ring.add(torus)
    const glowMat = new THREE.MeshBasicMaterial({ color: LAVENDER, transparent: true, opacity: 0.35 })
    glowMat.name = `${def.label[0]} · Glow`
    const glow = new THREE.Mesh(new THREE.TorusGeometry(def.r, 0.42, 24, 128), glowMat)
    ring.add(glow)
    // inner membrane: soft disc you fly through
    const memMat = new THREE.MeshBasicMaterial({
      map: makeGlowTexture(i === 2 ? '#B8A8FF' : '#DCD4FF'),
      transparent: true,
      opacity: 0.55,
      depthWrite: false,
    })
    memMat.name = `${def.label[0]} · Membrane`
    const membrane = new THREE.Mesh(new THREE.CircleGeometry(def.r - 0.2, 64), memMat)
    membrane.position.z = -0.05
    ring.add(membrane)
    const label = makeLabelSprite(def.label)
    label.position.set(0, def.r + 1.2, 0)
    ring.add(label)
    ring.position.z = def.z
    ringsGroup.add(ring)
    ringMeshes.push(ring)
    asset.register(def.id, ring, { name: `Portal · ${def.label[0]}`, parent: undefined })
  })
  scene.add(ringsGroup)

  // ----- floating memory prints -----
  const cardDefs = [
    { hueA: '#FFD9A0', hueB: '#E88B5D', motif: 'sunset', pos: [6.4, 1.6, -17], rot: [0.05, -0.5, 0.06] },
    { hueA: '#BFD8FF', hueB: '#7A9BE0', motif: 'friends', pos: [-6.6, -1.2, -20], rot: [-0.04, 0.5, -0.05] },
    { hueA: '#D8ECCB', hueB: '#8FBF7F', motif: 'hills', pos: [5.6, -1.8, -32], rot: [0.06, -0.45, 0.04] },
    { hueA: '#FFE3EF', hueB: '#E59AB8', motif: 'confetti', pos: [-5.4, 2.0, -35], rot: [-0.05, 0.42, -0.07] },
    { hueA: '#FFF3C9', hueB: '#E8C86A', motif: 'friends', pos: [-6.0, 0.4, -8], rot: [0.03, 0.5, 0.05] },
    { hueA: '#D7F0F5', hueB: '#7FB8C9', motif: 'sunset', pos: [6.2, -0.6, -44], rot: [-0.06, -0.5, 0.05] },
  ]
  const cardsGroup = new THREE.Group()
  const cardBases = []
  cardDefs.forEach((def, i) => {
    const mat = new THREE.MeshBasicMaterial({ map: makePhotoCardTexture(def.hueA, def.hueB, def.motif) })
    mat.name = `Memory print ${i + 1}`
    const card = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 3.25), mat)
    card.position.set(...def.pos)
    card.rotation.set(...def.rot)
    cardsGroup.add(card)
    cardBases.push({ mesh: card, baseY: def.pos[1], phase: i * 1.3, baseRotZ: def.rot[2] })
  })
  scene.add(cardsGroup)
  asset.register('memory-prints', cardsGroup, { name: 'Memory prints' })

  // ----- dust particles for depth -----
  const COUNT = 220
  const positions = new Float32Array(COUNT * 3)
  for (let i = 0; i < COUNT; i++) {
    const a = Math.random() * Math.PI * 2
    const r = 1.5 + Math.random() * 7.5
    positions[i * 3] = Math.cos(a) * r
    positions[i * 3 + 1] = Math.sin(a) * r
    positions[i * 3 + 2] = 6 - Math.random() * 58
  }
  const pGeo = new THREE.BufferGeometry()
  pGeo.setAttribute('position', new THREE.BufferAttribute(positions, 3))
  const pMat = new THREE.PointsMaterial({ map: makeDotTexture(), size: 0.35, transparent: true, depthWrite: false, sizeAttenuation: true })
  pMat.name = 'Ambient dust'
  const particles = new THREE.Points(pGeo, pMat)
  scene.add(particles)
  asset.register('dust', particles, { name: 'Ambient dust' })

  // ----- arrival bloom: the deepest circle, Sec A -----
  const arrival = new THREE.Group()
  const bloomMat = new THREE.MeshBasicMaterial({ map: makeGlowTexture('#C9BFFF'), transparent: true, depthWrite: false })
  bloomMat.name = 'Arrival · Bloom'
  const bloom = new THREE.Mesh(new THREE.CircleGeometry(4.0, 64), bloomMat)
  arrival.add(bloom)
  const discMat = new THREE.MeshBasicMaterial({ color: WARM })
  discMat.name = 'Arrival · Disc'
  const disc = new THREE.Mesh(new THREE.CircleGeometry(2.1, 64), discMat)
  disc.position.z = 0.02
  arrival.add(disc)
  const innerRingMat = new THREE.MeshBasicMaterial({ color: INDIGO })
  innerRingMat.name = 'Arrival · Ring'
  const innerRing = new THREE.Mesh(new THREE.TorusGeometry(2.1, 0.1, 20, 96), innerRingMat)
  innerRing.position.z = 0.03
  arrival.add(innerRing)
  const arrivalLabel = makeLabelSprite(['Sec A', 'Your inner circle'], { scale: 0.85 })
  arrivalLabel.position.set(0, 0, 0.06)
  arrival.add(arrivalLabel)
  arrival.position.set(0, 0, -52)
  scene.add(arrival)
  asset.register('arrival', arrival, { name: 'Arrival · Sec A' })

  asset.register('camera', camera, { name: 'Dive camera' })

  // ----- ambient animation (absolute-time poses) -----
  asset.registerAnimation('ambient', {
    name: 'Ambient drift',
    objectId: 'memory-prints',
    duration: 12,
    sample(time) {
      for (const c of cardBases) {
        c.mesh.position.y = c.baseY + Math.sin(time * 0.6 + c.phase) * 0.28
        c.mesh.rotation.z = c.baseRotZ + Math.sin(time * 0.4 + c.phase) * 0.035
      }
      ringMeshes.forEach((ring, i) => {
        const s = 1 + Math.sin(time * 1.6 + i * 1.1) * 0.015
        ring.scale.set(s, s, 1)
      })
      particles.rotation.z = time * 0.012
      const b = 1 + Math.sin(time * 2.2) * 0.04
      bloom.scale.set(b, b, 1)
    },
  })

  // ----- camera dive shot (sampled eased path, absolute times) -----
  const easeInOut = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2)
  const DIVE_T = 10.5 // dive ends, then hold
  const pathPoint = (t) => {
    const p = easeInOut(Math.min(t / DIVE_T, 1))
    const z = 10 + (-42 - 10) * p
    const x = Math.sin(t * 0.9) * 0.55 * (1 - p * 0.6)
    const y = 0.6 + Math.sin(t * 0.7) * 0.35 * (1 - p * 0.5)
    return { pos: [x, y, z], look: [x * 0.4, y * 0.4, z - 14] }
  }
  const keyframes = []
  for (let t = 0; t <= 12.001; t += 0.5) {
    const tt = Math.min(t, 12)
    const { pos, look } = pathPoint(tt)
    // hold the final framing for the last 1.5s
    if (tt > DIVE_T) {
      const end = pathPoint(DIVE_T)
      keyframes.push({ time: tt, position: end.pos, lookAt: [0, 0, -52] })
    } else {
      keyframes.push({ time: tt, position: pos, lookAt: look })
    }
  }
  asset.registerShot('circle-dive', {
    camera: 'camera',
    duration: 12,
    keyframes,
  })
  asset.registerTrack('shots', { clips: [{ shotId: 'circle-dive' }] })

  // ----- titles -----
  asset.registerText('title', {
    name: 'Titles',
    text: '',
    position: [0.5, 0.1],
    visible: true,
    style: { font: '600 44px Inter, system-ui, sans-serif', color: '#221D16', align: 'center', backgroundColor: '#FBF7F2CC', padding: 14 },
  })
  asset.registerTrack('title-track', {
    type: 'subtitle',
    targetId: 'title',
    name: 'Titles',
    clips: [
      { id: 't-open', start: 0, duration: 3.2, text: 'Circle Dive — circles within circles' },
      { id: 't-mid', start: 4.2, duration: 2.6, text: 'AKCE 2009  ›  CSE' },
      { id: 't-end', start: 8.6, duration: 3.3, text: 'Every circle holds smaller ones' },
    ],
  })

  return {
    scene,
    camera,
    dispose() {
      scene.traverse((obj) => {
        if (obj.geometry) obj.geometry.dispose()
        if (obj.material) {
          const mats = Array.isArray(obj.material) ? obj.material : [obj.material]
          mats.forEach((m) => {
            if (m.map) m.map.dispose()
            m.dispose()
          })
        }
      })
    },
  }
}
