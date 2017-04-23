using VSGI;

/**
 * Route based on exact path matching.
 */
[Version (since = "0.3")]
public class Valum.PathRoute : Valum.Route {

	/**
	 * The path matched by this route.
	 */
	[Version (since = "0.3")]
	public string path { construct; get; }

	[Version (since = "0.3")]
	public PathRoute (Method method, string path, Middleware middleware) {
		Object (method: method, path: path, middleware: middleware);
	}

	public override bool match (Request req, Context ctx) {
		return req.uri.get_path () == path;
	}

	public override string to_url_from_hash (HashTable<string, string>? @params = null) {
		return path;
	}
}
