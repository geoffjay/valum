/*
 * This file is part of Valum.
 *
 * Valum is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Valum is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Valum.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using VSGI;

namespace Valum {

	/**
	 * Route based on the rule system.
	 *
	 * The actual rule is compiled down to {@link GLib.Regex} and starts
	 * matching after the leading slash '/' in the request URI path.
	 *
	 * @since 0.3
	 */
	public class RuleRoute : RegexRoute {

		/**
		 * @since 0.3
		 */
		public string rule { construct; get; }

		/**
		 * Create a Route for a given callback from a rule.
		 *
		 * @since 0.0.1
		 *
		 * @param rule  compiled down ot a regular expression and captures all
		 *              paths if set to 'null'
		 * @param types type mapping to figure out types in rule or 'null' to
		 *              prevent any form of typing
		 * @param flags enable rule features
		 */
		public RuleRoute (Method                    method,
		                  string                    rule,
		                  HashTable<string, Regex>? types,
		                  owned HandlerCallback     handler) throws RegexError {
			var pattern = new StringBuilder ();

			var @params = /(<(?:\w+:)?\w+>)/.split_full (rule);

			pattern.append ("^");

			foreach (var p in @params) {
				if (p[0] != '<') {
					// regular piece of route
					pattern.append (Regex.escape_string (p));
				} else {
					// extract parameter
					var cap  = p.slice (1, p.length - 1).split (":", 2);
					var type = cap.length == 1 ? "string" : cap[0];
					var key  = cap.length == 1 ? cap[0] : cap[1];

					if (types == null) {
						pattern.append_printf ("(?<%s>\\w+)", key);
					} else {
						if (!types.contains (type))
							throw new RegexError.COMPILE ("using an undefined type %s", type);

						pattern.append_printf ("(?<%s>%s)", key, types[type].get_pattern ());
					}
				}
			}

			pattern.append ("$");

			base (method, new Regex (pattern.str, RegexCompileFlags.OPTIMIZE), (owned) handler);
		}
	}
}
