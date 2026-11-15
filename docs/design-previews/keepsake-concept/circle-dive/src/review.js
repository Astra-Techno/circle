export const review = {
  status: 'passed',
  checks: [
    {
      name: 'Opening frame: AKCE 2009 portal, labels, prints, dust',
      status: 'passed',
      evidence: 'docs/review/frame-00-opening.png — ring crisp, label pill readable, no clipping or overexposure',
    },
    {
      name: 'Mid-dive frame at 5.5s: passes CSE ring toward Sec A',
      status: 'passed',
      evidence: 'docs/review/frame-02-middive.png — depth layers read correctly, subtitle track swaps, no wall penetration',
    },
    {
      name: 'Arrival frame at 10.8s: Sec A bloom framing',
      status: 'passed',
      evidence: 'docs/review/frame-03-arrival.png — reframed after defect fix (camera was inside the bloom); ring, disc and label now fully visible',
    },
    {
      name: 'Absolute-time animation sampling',
      status: 'passed',
      evidence: 'sample(time) computes poses purely from t (cards, ring pulse, dust, bloom); seek 0 → 5.5 → 10.8 rendered deterministic frames',
    },
    {
      name: 'Material names',
      status: 'passed',
      evidence: 'All materials named by purpose (Portal rings/glows/membranes, memory prints, dust, arrival set); no unnamed placeholders',
    },
  ],
  limitations: [
    'Stylised flat motion-design look (MeshBasic), no physical lighting — deliberate for a UI-transition concept',
    'Photo prints use abstract canvas art, not real photos; final app uses real group photos',
  ],
}
