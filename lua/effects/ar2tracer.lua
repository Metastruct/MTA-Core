local creating = false

function EFFECT:Init( data )
	if creating then return end
	self.Position = data:GetStart()
	self.WeaponEnt = data:GetEntity()
	self.Attachment = data:GetAttachment()
	self.StartPos = self:GetTracerShootPos(self.Position,self.WeaponEnt,self.Attachment)
	self.EndPos = data:GetOrigin()
	creating = true
	util.ParticleTracerEx("cmb_tracer",self.StartPos,self.EndPos,1,0,-1)
	creating = false
end
function EFFECT:Render()
	return false
end