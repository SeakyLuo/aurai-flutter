// DMX Responses：用完整正文和工具记录续接，不引用特定 Azure 资源的对象。
const body = request.body;
body.store = false;
delete body.previous_response_id;
if (Array.isArray(body.input)) {
  body.input = body.input.filter(function(item) {
    // 远端思考对象不具备跨资源可移植性；正文和工具调用仍完整保留。
    return item.type !== 'reasoning';
  }).map(function(item) {
    const copy = Object.assign({}, item);
    delete copy.id;
    return copy;
  });
}
return { path: request.path, body: body };
