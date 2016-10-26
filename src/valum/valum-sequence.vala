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

namespace Valum {

	/**
	 * Produce a handler sequence of 'a' and 'b'.
	 */
	[Version (since = "0.3")]
	public HandlerCallback sequence (owned HandlerCallback a, owned HandlerCallback b) {
		return (req, res, next, ctx) => {
			return a (req, res, () => {
				return b (req, res, next, ctx);
			}, ctx);
		};
	}
}
