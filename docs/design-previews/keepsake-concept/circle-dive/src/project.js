import { createScene } from './scene.js'

export function createProject() {
  return {
    id: 'circle-dive',
    name: 'Circle Dive — Keepsake concept',
    defaultSceneId: 'main',
    scenes: [{ id: 'main', name: 'Circle Dive', createScene }],
  }
}
