#include <cstdio>
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include "model.h"
#include "platform_egl.h"
using namespace sk;
int main(int argc,char**argv){
  if(!eglHeadlessInit()){puts("no gl");return 1;}
  g_assetDir="/home/claude/eab71334-web/sabak-engine/assets";
  Renderer r;if(!r.init(64,64)){puts("r");return 1;}
  printf("humanAvailable=%d\n",(int)humanAvailable());
  CharDef cd;cd.name="Driver";if(getenv("HD"))cd.hairDens=atof(getenv("HD"));if(getenv("OF"))cd.outfit=atoi(getenv("OF"));if(getenv("HS"))cd.hair=atoi(getenv("HS"));Model m;
  if(!buildHuman(r,cd,m)){puts("buildHuman failed");return 1;}
  printf("prims=%zu mats=%zu nodes=%zu joints=%zu anims=%zu builtin=%d\n",m.prims.size(),m.mats.size(),m.nodeName.size(),m.joints.size(),m.anims.size(),m.builtin);
  for(size_t i=0;i<m.prims.size();i++)printf("prim %zu mat=%d kind=%d tris=%zu img=%zu\n",i,m.prims[i].mat,m.mats[m.prims[i].mat].kind,m.prims[i].ci.size()/3,m.mats[m.prims[i].mat].img.size());size_t tris=0;for(auto&p:m.prims)tris+=p.ci.size()/3;printf("tris=%zu\n",tris);
  for(size_t i=0;i<m.nodeName.size();i++)printf("%zu %s role=%s parent=%d\n",i,m.nodeName[i].c_str(),m.boneRole((int)i).c_str(),m.parent[i]);
  for(auto&a:m.anims)printf("anim %s %.2f\n",a.name.c_str(),a.dur);
  auto K=[&](ClipDef&d,int n,float t,float x,float y,float z,float px=0,float py=0,float pz=0){ClipKey k;k.t=t;k.rot={x,y,z};k.pos={px,py,pz};k.ease=1;d.keys[n].push_back(k);};
  // bone ids: 0 root,1 spine05,2 spine03,3 spine01,4/5 clav L/R,6 neck,7 head,10/14 uparm L/R,11/15 loarm,46/49 upleg L/R,47/50 loleg,48/51 foot
  struct B{int n;float x,y,z,px,py,pz;};
  auto P=[&](ClipDef&d,float t,std::vector<B> bs){
    // default arms-down offsets unless overridden
    bool has[64]={0};for(auto&b:bs)has[b.n]=1;
    if(!has[10])bs.push_back({10,-0,0,-38,0,0,0});if(!has[14])bs.push_back({14,-0,0,38,0,0,0});
    for(auto&b:bs)K(d,b.n,t,b.x,b.y,b.z,b.px,b.py,b.pz);};
  auto mk=[&](const char*nm,float dur,bool loop,bool inPlace)->ClipDef&{int c=m.addClip(nm,"");ClipDef&d=m.clips[c];d.dur=dur;d.loop=loop;d.inPlace=inPlace;return d;};
  // convention found by preview: Z abducts arm (L +, R -), leg X- = thigh forward, knee X+ bends, arm X+ = forward (verified in sheet)
  {ClipDef&d=mk("idle",3,true,false);for(int i=0;i<=2;i++){float t=i*1.5f,b=i==1?1.5f:0;P(d,t,{{3,b,0,0,0,0,0},{7,-b*.5f,0,0,0,0,0},{11,-8,0,0,0,0,0},{15,-8,0,0,0,0,0}});}}
  auto gait=[&](const char*nm,float dur,float leg,float arm,float knee,float bob,float lean,float rot,float sway){ClipDef&d=mk(nm,dur,true,true);
    const int N=8;for(int i=0;i<=N;i++){float t=i*dur/N,ph=i*6.2831853f/N,s=std::sin(ph),co=std::cos(ph);
      float kL=6+knee*std::max(0.f,co)*leg/30.f*1.2f, kR=6+knee*std::max(0.f,-co)*leg/30.f*1.2f;
      float elL=15+std::fabs(arm)*0.45f*(0.5f+0.5f*s), elR=15+std::fabs(arm)*0.45f*(0.5f-0.5f*s);
      P(d,t,{{46,-leg*s,0,0,0,0,0},{49,leg*s,0,0,0,0,0},{47,kL,0,0,0,0,0},{50,kR,0,0,0,0,0},
        {48,-8*s-4,0,0,0,0,0},{51,8*s-4,0,0,0,0,0},
        {10,-arm*0.9f*(-s),0,-36,0,0,0},{14,-arm*0.9f*s,0,36,0,0,0},{11,-elL,0,0,0,0,0},{15,-elR,0,0,0,0,0},
        {1,lean,rot*s,sway*s,0,0,0},{2,0,-rot*1.4f*s,-sway*0.6f*s,0,0,0},{3,0,-rot*0.5f*s,0,0,0,0},{7,0,rot*0.8f*s,0,0,0,0},
        {0,0,rot*0.6f*s,0,sway*0.35f*s,-bob*std::fabs(co),0}});}};
  auto turn=[&](const char*nm,float sg){ClipDef&d=mk(nm,1.0f,true,true);
    float L[5]={0,1,0,0,0},R[5]={0,0,0,1,0};
    for(int i=0;i<=4;i++){float t=i*0.25f;
      P(d,t,{{46,-24*L[i]*0.9f,0,-sg*6*L[i],0,0,0},{49,-24*R[i]*0.9f,0,sg*6*R[i],0,0,0},{47,6+30*L[i],0,0,0,0,0},{50,6+30*R[i],0,0,0,0,0},
        {1,2,sg*10*(L[i]+R[i]),0,0,0,0},{2,0,sg*6*(L[i]+R[i]),0,0,0,0},{7,0,-sg*10,0,0,0,0},{11,-14,0,0,0,0,0},{15,-14,0,0,0,0,0}});}};
  turn("turn_L",1);turn("turn_R",-1);
  gait("walk",1.1f,24,26,1.0f,1.8f,3,6,2.5f);
  gait("run",0.72f,46,60,1.6f,4.0f,12,9,3);
  {ClipDef&d=mk("sit_drive",2.0f,true,false);for(int i=0;i<=2;i++){float br=i==1?1.f:0.f;P(d,i*1.0f,{{46,-72,0,-4,0,0,0},{49,-72,0,4,0,0,0},{47,88,0,0,0,0,0},{50,88,0,0,0,0,0},{48,-6,0,0,0,0,0},{51,-6,0,0,0,0,0},
      {1,-2,0,0,0,0,0},{2,-2+br*.6f,0,0,0,0,0},{3,-2,0,0,0,0,0},{7,6,0,0,0,0,0},
      {10,-44,0,-14,0,0,0},{14,-44,0,14,0,0,0},{11,-30,0,0,0,0,0},{15,-30,0,0,0,0,0},{0,0,0,0,0,-40,-8}});}}
  // reach for the door handle (left arm out), then pull
  {ClipDef&d=mk("reach_handle",1.2f,false,true);
    P(d,0,{{11,-15,0,0,0,0,0}});
    P(d,0.5f,{{10,-65,0,-5,0,0,0},{11,-25,0,0,0,0,0},{1,6,-8,0,0,0,0}});
    P(d,0.8f,{{10,-65,0,-5,0,0,0},{11,-25,0,0,0,0,0},{1,6,-8,0,0,0,0}});
    P(d,1.2f,{{11,-15,0,0,0,0,0}});}
  // key from pocket (right hand to right front pocket and up)
  {ClipDef&d=mk("key_pocket",1.8f,false,true);
    P(d,0,{{14,0,0,36,0,0,0},{15,-12,0,0,0,0,0},{1,0,0,0,0,0,0}});
    P(d,0.45f,{{14,14,0,36,0,0,0},{15,-28,0,0,0,0,0},{1,8,-6,0,0,0,0},{48,0,0,0,0,0,0}});
    P(d,0.85f,{{14,16,0,36,0,0,0},{15,-34,0,0,0,0,0},{1,10,-8,0,0,0,0}});
    P(d,1.35f,{{14,-32,0,28,0,0,0},{15,-62,0,0,0,0,0},{1,3,-4,0,0,0,0},{7,10,0,0,0,0,0}});
    P(d,1.8f,{{14,-32,0,28,0,0,0},{15,-62,0,0,0,0,0},{1,3,-4,0,0,0,0},{7,10,0,0,0,0,0}});}
  // exit car: from seated to standing beside it (root rises, legs unfold)
  {ClipDef&d=mk("exit_car",1.6f,false,false);
    P(d,0,{{46,-80,0,0,0,0,0},{49,-80,0,0,0,0,0},{47,80,0,0,0,0,0},{50,80,0,0,0,0,0},{10,-55,0,-10,0,0,0},{14,-55,0,10,0,0,0},{11,-45,0,0,0,0,0},{15,-45,0,0,0,0,0},{0,0,0,0,0,-42,0}});
    P(d,0.6f,{{46,-56,0,-10,0,0,0},{49,-40,0,0,0,0,0},{47,70,0,0,0,0,0},{50,55,0,0,0,0,0},{1,16,0,0,0,-14,5},{10,-40,0,-5,0,0,0},{11,-30,0,0,0,0,0},{0,0,0,0,0,-30,0}});
    P(d,1.1f,{{46,-35,0,-10,0,0,0},{49,-15,0,0,0,0,0},{47,40,0,0,0,0,0},{50,20,0,0,0,0,0},{1,15,0,0,0,-10,0}});
    P(d,1.6f,{{11,-8,0,0,0,0,0},{15,-8,0,0,0,0,0}});}
  {ClipDef&d=mk("enter_car",1.6f,false,false);
    P(d,0,{{11,-8,0,0,0,0,0},{15,-8,0,0,0,0,0}});
    P(d,0.5f,{{46,-35,0,-10,0,0,0},{49,-15,0,0,0,0,0},{47,40,0,0,0,0,0},{50,20,0,0,0,0,0},{1,15,0,0,0,-10,0}});
    P(d,1.0f,{{46,-56,0,-10,0,0,0},{49,-40,0,0,0,0,0},{47,70,0,0,0,0,0},{50,55,0,0,0,0,0},{1,16,0,0,0,-14,5},{0,0,0,0,0,-30,0}});
    P(d,1.6f,{{46,-80,0,0,0,0,0},{49,-80,0,0,0,0,0},{47,80,0,0,0,0,0},{50,80,0,0,0,0,0},{10,-55,0,-10,0,0,0},{14,-55,0,10,0,0,0},{11,-45,0,0,0,0,0},{15,-45,0,0,0,0,0},{0,0,0,0,0,-42,0}});}
  {ClipDef&d=mk("close_door",1.0f,false,true);
    P(d,0,{{11,-8,0,0,0,0,0}});P(d,0.4f,{{10,-55,0,-20,0,0,0},{11,-20,0,0,0,0,0},{1,4,5,0,0,0,0}});P(d,0.7f,{{10,-40,0,-5,0,0,0},{11,-15,0,0,0,0,0}});P(d,1.0f,{{11,-8,0,0,0,0,0}});}
  for(size_t c=1;c<m.clips.size();c++){ClipDef&d=m.clips[c];std::vector<float> ts;for(auto&kv:d.keys)for(auto&k:kv.second)ts.push_back(k.t);std::sort(ts.begin(),ts.end());ts.erase(std::unique(ts.begin(),ts.end(),[](float a,float b){return std::fabs(a-b)<1e-4f;}),ts.end());
    for(auto&kv:d.keys){auto&v=kv.second;for(float t:ts){bool f=false;for(auto&k:v)if(std::fabs(k.t-t)<1e-4f)f=true;if(!f){ClipKey k;k.t=t;k.rot={0,0,0};k.pos={0,0,0};k.ease=1;v.push_back(k);}}
      std::sort(v.begin(),v.end(),[](const ClipKey&a,const ClipKey&b){return a.t<b.t;});}}
  for(size_t c=0;c<m.clips.size();c++)m.bakeClip((int)c);
  {size_t nm=m.prims[0].md.size();for(auto&p:m.prims)if(p.md.empty())p.md.assign(nm,std::vector<float>(p.cv.size()*3,0.f));}
  std::string err;bool ok=exportGlb(m,argc>1?argv[1]:"human.glb",err);printf("export=%d %s\n",(int)ok,err.c_str());
}
