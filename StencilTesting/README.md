#  Two ways to do stencil testing

- set MTLRenderPassDescriptor.stencilAttachment.clearStencil = 1;
then set MTLStencilDescriptor.depthStencilPassOperation = .zero;
then check stencil by set MTLStencilDescriptor.stencilCompareFunction = .notEqual;

- set MTLRenderPassDescriptor.stencilAttachment.clearStencil = 0;
set MTLRenderCommandEncoder.setStencilReferenceValue = 1;
then set MTLStencilDescriptor.depthStencilPassOperation = .replace;
then check stencil by set MTLStencilDescriptor.stencilCompareFunction = .notEqual;
