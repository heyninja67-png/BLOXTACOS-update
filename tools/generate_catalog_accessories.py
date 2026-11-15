from pathlib import Path
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT=Path('assets/catalog/models')
OUT.mkdir(parents=True, exist_ok=True)

COLORS={
 'blue':(35,106,190,255),'blue_light':(64,151,224,255),'navy':(24,52,92,255),
 'black':(22,29,37,255),'dark':(48,59,70,255),'gold':(242,190,62,255),
 'gold_light':(255,220,112,255),'green':(48,162,103,255),'green_light':(79,204,139,255),
 'red':(190,58,55,255),'red_light':(231,88,76,255),'white':(226,237,242,255),
 'lens':(35,65,84,255),'shirt':(52,123,204,255)
}

def mat(c, metal=0.0, rough=.52):
    return PBRMaterial(name='BloxTacos_'+str(c), baseColorFactor=COLORS[c], metallicFactor=metal, roughnessFactor=rough)

def move(mesh, xyz):
    mesh.apply_translation(xyz)
    return mesh

def ellipsoid(scale, pos, c, name, subdiv=3, metal=0.0, rough=.55):
    m=trimesh.creation.icosphere(subdivisions=subdiv, radius=1.0)
    m.apply_scale(scale); move(m,pos)
    m.visual.material=mat(c,metal,rough)
    m.metadata['name']=name
    return m

def cyl(radius,height,pos,c,name,sections=40,axis='y',metal=0.0):
    m=trimesh.creation.cylinder(radius=radius,height=height,sections=sections)
    if axis=='x':
        m.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[0,1,0]))
    elif axis=='y':
        m.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[1,0,0]))
    move(m,pos); m.visual.material=mat(c,metal,.44); m.metadata['name']=name
    return m

def torus(major,minor,pos,c,name,plane='xz',metal=0.0):
    m=trimesh.creation.torus(major_radius=major,minor_radius=minor,major_sections=48,minor_sections=12)
    if plane=='xz':
        m.apply_transform(trimesh.transformations.rotation_matrix(np.pi/2,[1,0,0]))
    move(m,pos); m.visual.material=mat(c,metal,.38); m.metadata['name']=name
    return m

def box(extents,pos,c,name):
    m=trimesh.creation.box(extents=extents); move(m,pos); m.visual.material=mat(c,0,.5); m.metadata['name']=name
    return m

def add_cone(radius,height,pos,c,name,sections=8):
    m=trimesh.creation.cone(radius=radius,height=height,sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(-np.pi/2,[1,0,0])) # cone Z axis -> +Y
    move(m,pos); m.visual.material=mat(c,.18,.35); m.metadata['name']=name
    return m

def export(item_id, meshes):
    scene=trimesh.Scene()
    for i,m in enumerate(meshes):
        scene.add_geometry(m,geom_name=f'{item_id}_{i}_{m.metadata.get("name","part")}',node_name=f'{item_id}_{i}')
    path=OUT/f'{item_id}.glb'
    path.write_bytes(scene.export(file_type='glb'))
    print(path, path.stat().st_size, 'bytes', scene.bounds)

# Accessories sit at avatar-root scale (approx. 1.7 m tall); forward is -Z.
# Boné: soft dome, brim, stitched seam and small front patch.
export('classic_cap',[
    ellipsoid((.39,.25,.39),(0,1.68,0),'blue','CapDome'),
    ellipsoid((.46,.035,.35),(0,1.55,-.16),'navy','CapBrim'),
    torus(.365,.018,(0,1.58,0),'blue_light','CapSeam','xz'),
    ellipsoid((.105,.07,.025),(0,1.70,-.385),'gold','CapPatch',2)
])
# Óculos: two circular frames, tinted lenses, bridge and side arms.
export('retro_shades',[
    torus(.145,.035,(-.205,1.48,-.385),'black','LeftFrame','xy'),
    torus(.145,.035,(.205,1.48,-.385),'black','RightFrame','xy'),
    cyl(.128,.026,(-.205,1.48,-.397),'lens','LeftLens',32,'z'),
    cyl(.128,.026,(.205,1.48,-.397),'lens','RightLens',32,'z'),
    ellipsoid((.10,.025,.035),(0,1.49,-.39),'gold','Bridge',2),
    ellipsoid((.26,.018,.025),(-.46,1.49,-.29),'black','LeftTemple',2),
    ellipsoid((.26,.018,.025),(.46,1.49,-.29),'black','RightTemple',2)
])
# Crown: rounded rim, band, five tapered points and small gemstones.
crown=[torus(.31,.055,(0,1.66,0),'gold','CrownRim','xz',.72),
        cyl(.31,.17,(0,1.69,0),'gold','CrownBand',48,'y',.7)]
for i,x in enumerate([-.25,-.13,0,.13,.25]):
    crown.append(add_cone(.07 if i%2 else .085,.26 if i%2 else .32,(x,1.92,0),'gold_light',f'CrownPoint{i}'))
for x in [-.17,0,.17]: crown.append(ellipsoid((.045,.05,.025),(x,1.69,-.30),'red','CrownGem',2,metal=.35))
export('gold_crown',crown)
# Visor: curved top, front peak, reinforced band.
export('green_visor',[
    ellipsoid((.40,.12,.38),(0,1.66,0),'green','VisorTop'),
    ellipsoid((.48,.035,.34),(0,1.57,-.17),'green_light','VisorPeak'),
    torus(.35,.035,(0,1.57,0),'green','VisorBand','xz'),
    ellipsoid((.11,.06,.018),(0,1.68,-.37),'white','VisorLogo',2)
])
# Backpack: shaped body, padded front pocket, shoulder straps and seams.
export('red_backpack',[
    ellipsoid((.34,.43,.22),(0,1.02,.43),'red','PackBody'),
    ellipsoid((.25,.20,.10),(0,.90,.625),'red_light','PackPocket'),
    ellipsoid((.055,.36,.08),(-.29,1.10,.24),'dark','LeftStrap'),
    ellipsoid((.055,.36,.08),(.29,1.10,.24),'dark','RightStrap'),
    ellipsoid((.14,.045,.022),(0,1.22,.635),'gold','PackBadge',2)
])
# Halo: ring in a horizontal plane plus a small star-like cluster.
halo=[torus(.43,.045,(0,2.00,0),'gold','HaloRing','xz',.65)]
for i in range(8):
    a=2*np.pi*i/8
    halo.append(ellipsoid((.045,.055,.045),(.43*np.cos(a),2.0,.43*np.sin(a)),'gold_light',f'HaloSpark{i}',2,.35))
export('star_halo',halo)
# Headphones: over-head padded band, ear shells, cushions and metallic discs.
export('headphones',[
    torus(.36,.065,(0,1.63,0),'black','Headband','xz'),
    ellipsoid((.13,.20,.14),(-.39,1.48,0),'blue','LeftCup'),
    ellipsoid((.13,.20,.14),(.39,1.48,0),'blue','RightCup'),
    ellipsoid((.075,.13,.04),(-.40,1.48,-.12),'blue_light','LeftPad'),
    ellipsoid((.075,.13,.04),(.40,1.48,-.12),'blue_light','RightPad'),
    ellipsoid((.06,.06,.025),(-.40,1.48,-.16),'gold','LeftBadge',2,.4),
    ellipsoid((.06,.06,.025),(.40,1.48,-.16),'gold','RightBadge',2,.4)
])
# Scarf: neck ring and a cloth tail falling over chest.
export('classic_scarf',[
    torus(.28,.105,(0,1.28,0),'red','ScarfWrap','xz'),
    ellipsoid((.14,.30,.085),(.16,1.02,-.22),'red_light','ScarfTail'),
    ellipsoid((.15,.055,.09),(.16,.87,-.22),'red','ScarfHem')
])
# Chain: two fine gold loops and a central pendant.
export('gold_chain',[
    torus(.28,.025,(0,1.28,0),'gold','ChainLoop','xz',.82),
    torus(.235,.016,(0,1.25,0),'gold_light','InnerChain','xz',.88),
    ellipsoid((.075,.09,.045),(0,1.02,-.28),'gold','Pendant',2,.78,.28),
    ellipsoid((.026,.034,.016),(0,1.02,-.325),'red','PendantStone',2,.3,.25)
])
# Shirt badge: round stitched patch, star-like raised center.
export('blue_tee',[
    cyl(.18,.045,(0,1.14,-.34),'navy','PatchBacking',40,'z'),
    cyl(.145,.052,(0,1.14,-.37),'blue_light','PatchFace',40,'z'),
    ellipsoid((.075,.10,.035),(0,1.14,-.41),'gold','PatchEmblem',2,.3)
])
