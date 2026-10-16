"""Quick checks for reference geometry, deduplication and reversible overlay."""
from reference import Reference, VECTORS, load_background, ray_masks, scenarios
from pathlib import Path
import json

root=Path(__file__).resolve().parents[3]
background=load_background(root/'radar/p5a/background/base/background_bytes.mem')
assert len(background)==1056
for page in range(8):
    assert background[page*132+128:page*132+132] == bytes(4)

# Inverse microsteps must recover every canonical vector exactly.
c,s=VECTORS[180]; phase=(63+180*15)%64
for angle in range(180,0,-1):
    previous=(phase-15)%64
    for _ in range(2+(previous+15)//64):
        s-=c>>7;c+=s>>7
    assert (c,s)==VECTORS[angle-1]
    phase=previous
assert (c,s,phase)==(1<<15,0,63)

checked=0
for continuous in (False,True):
    plain=Reference(background,continuous=continuous)
    beam=Reference(background,continuous=continuous,beam=True)
    for case in scenarios():
        plain.request(**case)
        no_beam=beam.request(**case)
        assert no_beam==plain.ram
        overlay=bytes(beam.ram); saved=beam.beam
        beam.remove_beam()
        assert beam.ram==plain.ram
        if saved:
            beam.toggle(*saved);beam.beam=saved
        assert bytes(beam.ram)==overlay
        checked+=1

# XOR mask grouping must produce a set of pixels, even when near-horizontal
# or near-vertical adjacent radial samples share a pixel/byte.
for angle in range(181):
    masks=ray_masks(angle)
    assert all(0<mask<256 for mask in masks.values())
    assert sum(mask.bit_count() for mask in masks.values())<=43

result=dict(reference_requests_checked=checked,canonical_inverse_angles=180,
            beam_removal_byte_exact=True,hidden_columns_zero=True)
print(json.dumps(result,indent=2))
