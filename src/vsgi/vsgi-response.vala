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
using Soup;

namespace VSGI {
	/**
	 * Response representing a request resource.
	 *
	 * @since 0.0.1
	 */
	public abstract class Response : Object {

		/**
		 * Request to which this response is responding.
		 *
		 * @since 0.1
		 */
		public Request request { construct; get; }

		/**
		 * Response status.
		 *
		 * @since 0.0.1
		 */
		public virtual uint status { get; set; default = global::Soup.Status.OK; }

		/**
		 * Response status message.
		 *
		 * @since 0.3
		 */
		public virtual string? reason_phrase { owned get; set; default = null; }

		/**
		 * Response headers.
		 *
		 * @since 0.0.1
		 */
		public abstract MessageHeaders headers { get; }

		/**
		 * Response cookies extracted from the 'Set-Cookie' header.
		 *
		 * @since 0.3
		 */
		public SList<Cookie> cookies {
			owned get {
				var cookies     = new SList<Cookie> ();
				var cookie_list = headers.get_list ("Set-Cookie");

				if (cookie_list == null)
					return cookies;

				foreach (var cookie in header_parse_list (cookie_list))
					if (cookie != null)
						cookies.prepend (Cookie.parse (cookie, request.uri));

				cookies.reverse ();

				return cookies;
			}
		}

		/**
		 * Tells if the head has been written in the connection
		 * {@link GLib.OutputStream}.
		 *
		 * This property can only be set internally.
		 *
		 * @since 0.2
		 */
		public virtual bool head_written { get; protected set; default = false; }

		/**
		 * Placeholder for the response body.
		 *
		 * @since 0.3
		 */
		protected OutputStream? _body = null;

		/**
		 * Response body.
		 *
		 * On the first attempt to access the response body stream, the status
		 * line and headers will be written synchronously in the response
		 * stream. 'write_head_async' have to be used explicitly to perform a
		 * non-blocking operation.
		 *
		 * The provided stream is safe for transfer encoding and will filter
		 * the stream properly if it's chunked.
		 *
		 * Typically, this would involve appling chunked encoding, buffering,
		 * transparent compression and other kind of filters required by the
		 * implementation.
		 *
		 * For CGI-ish protocols, the server will generally deal with transfer
		 * encoding automatically, so the default implementation is to simply
		 * return the base_stream.
		 *
		 * @since 0.2
		 */
		public OutputStream body {
			get {
				try {
					// write head synchronously
					if (!this.head_written) {
						size_t bytes_written;
						this.write_head (out bytes_written);
					}
				} catch (IOError err) {
					warning ("could not write the head in the connection stream: %s", err.message);
				}

				return _body ?? this.request.connection.output_stream;
			}
		}

		/**
		 * Obtain the body stream asynchronously.
		 *
		 * Unlike the {@link VSGI.Request.body} property, this allow you to
		 * asynchronously obtain the body when the head has been written in
		 * a single call.
		 *
		 * @since 0.3
		 */
		public async OutputStream get_body_async (int priority             = GLib.Priority.DEFAULT,
		                                          Cancellable? cancellable = null,
		                                          out size_t   bytes_written) throws Error {
			if (head_written) {
				bytes_written = 0;
			} else {
				yield write_head_async (priority, cancellable, out bytes_written);
			}
			return body;
		}

		/**
		 * Produce the head of this response including the status line, the
		 * headers and the newline preceeding the body as it would be written in
		 * the base stream.
		 *
		 * The default implementation will produce a valid HTTP/1.1 head
		 * including the status line and headers.
		 *
		 * @since 0.2
		 */
		protected virtual uint8[]? build_head () {
			var head = new StringBuilder ();

			// status line
			head.append_printf ("HTTP/%s %u %s\r\n",
			                    this.request.http_version == HTTPVersion.@1_0 ? "1.0" : "1.1",
			                    status,
			                    reason_phrase ?? Status.get_phrase (status));

			// headers
			this.headers.foreach ((name, header) => {
				head.append_printf ("%s: %s\r\n", name, header);
			});

			// newline preceeding the body
			head.append ("\r\n");

			return head.str.data;
		}

		/**
		 * Write status line and headers into the base stream.
		 *
		 * This is invoked automatically when accessing the response body for
		 * the first time.
		 *
		 * @since 0.2
		 *
		 * @param bytes_written number of bytes written in the stream see
		 *                      {@link GLib.OutputStream.write_all}
		 * @return wether the head was effectively written
		 */
		public bool write_head (out size_t bytes_written, Cancellable? cancellable = null) throws IOError
			requires (!this.head_written)
		{
			var head = this.build_head ();

			if (head == null) {
				bytes_written = 0;
				this.head_written = true;
			} else {
				this.head_written = this.request.connection.output_stream.write_all (head,
				                                                                     out bytes_written,
				                                                                     cancellable);
			}

			return this.head_written;
		}

		/**
		 * Write status line and headers asynchronously.
		 *
		 * @since 0.2
		 *
		 * @param bytes_written number of bytes written in the stream see
		 *                      {@link GLib.OutputStream.write_all_async}
		 * @return wether the head was effectively written
		 */
		public async bool write_head_async (int priority = GLib.Priority.DEFAULT,
		                                    Cancellable? cancellable = null,
		                                    out size_t bytes_written) throws Error
			requires (!this.head_written)
		{
#if GIO_2_44
			var head = this.build_head ();

			if (head == null) {
				bytes_written = 0;
				this.head_written = true;
			} else {
				this.head_written = yield this.request.connection.output_stream.write_all_async (head,
																								 priority,
																								 cancellable,
																								 out bytes_written);
			}

			return this.head_written;
#else
			return write_head (out bytes_written, cancellable);
#endif
		}

		/**
		 * Apply a converter to the response body.
		 *
		 * If the payload is chunked, (eg. 'Transfer-Encoding: chunked') and the
		 * new content length is undetermined, it will remain chunked.
		 *
		 * @since 0.3
		 *
		 * @param converter      converter to stack on the response body
		 * @param content_length resulting value for the 'Content-Length' header
		 *                       or '-1' if the length is undetermined
		 */
		public void convert (Converter converter, int64 content_length = -1) {
			if (content_length >= 0) {
				headers.set_content_length (content_length);
			} else if (headers.get_encoding () == Soup.Encoding.CHUNKED) {
				// nothing to do
			} else {
				headers.set_encoding (Soup.Encoding.EOF);
			}
			_body = new ConverterOutputStream (_body ?? request.connection.output_stream, converter);
		}

		/**
		 * Expand a buffer into the response body.
		 *
		 * If the content length can be determine reliably (eg. no
		 * 'Content-Encoding' applied), it will be set as well.
		 *
		 * @since 0.3
		 */
		public bool expand (uint8[] buffer, Cancellable? cancellable = null) throws IOError {
			if (headers.get_list ("Content-Encoding") == null) {
				headers.set_content_length (buffer.length);
			}
			size_t bytes_written;
			return write_head (out bytes_written, cancellable) &&
			       body.write_all (buffer, out bytes_written, cancellable) &&
			       body.close (cancellable);
		}

		/**
		 * Expand a {@link GLib.Bytes} buffer into the response body.
		 *
		 * @since 0.3
		 */
		public bool expand_bytes (Bytes bytes, Cancellable? cancellable = null) throws IOError {
			return expand (bytes.get_data (), cancellable);
		}

		/**
		 * Expand a UTF-8 string into the response body.
		 *
		 * If not set already, the 'charset' parameter of the 'Content-Type'
		 * header will be set to 'UTF-8'. The media type will default to
		 * 'application/octet-stream' if not set already. Use {@link VSGI.Response.expand}
		 * to write data with arbitrairy charset.
		 *
		 * @since 0.3
		 */
		public bool expand_utf8 (string body, Cancellable? cancellable = null) throws IOError {
			HashTable<string, string> @params;
			var content_type = headers.get_content_type (out @params);
			if (content_type == null) {
				headers.set_content_type ("application/octet-stream", Soup.header_parse_param_list ("charset=UTF-8"));
			} else if (@params["charset"] == null) {
				@params["charset"] = "UTF-8";
				headers.set_content_type (content_type, @params);
			}
			return expand (body.data, cancellable);
		}

		/**
		 * @since 0.3
		 */
		public async bool expand_async (uint8[]      buffer,
		                                int          priority    = GLib.Priority.DEFAULT,
		                                Cancellable? cancellable = null) throws Error {
#if GIO_2_44
			headers.set_content_length (buffer.length);
			size_t bytes_written;
			return (yield write_head_async (priority, cancellable, out bytes_written)) &&
			       (yield body.write_all_async (buffer, priority, cancellable, out bytes_written)) &&
			       (yield body.close_async (priority, cancellable));
#else
			return expand (buffer, cancellable);
#endif
		}

		/**
		 * @since 0.3
		 */
		public async bool expand_bytes_async (Bytes        bytes,
		                                      int          priority    = GLib.Priority.DEFAULT,
		                                      Cancellable? cancellable = null) throws Error {
			return yield expand_async (bytes.get_data (), priority, cancellable);
		}

		/**
		 * @since 0.3
		 */
		public async bool expand_utf8_async (string       body,
		                                     int          priority    = GLib.Priority.DEFAULT,
		                                     Cancellable? cancellable = null) throws Error {
			return yield expand_async (body.data, priority, cancellable);
		}

		/**
		 * End the response properly, writting the head if missing.
		 *
		 * @since 0.3
		 */
		public bool end (Cancellable? cancellable = null) throws IOError {
			size_t bytes_written;
			return (head_written || write_head (out bytes_written, cancellable)) && body.close (cancellable);
		}

		/**
		 * @since 0.3
		 */
		public async bool end_async (int          priority    = GLib.Priority.DEFAULT,
		                             Cancellable? cancellable = null) throws Error {
			size_t bytes_written;
			return (head_written || yield write_head_async (priority, cancellable, out bytes_written)) &&
			       yield body.close_async (priority, cancellable);
		}

		/**
		 * Write the head before disposing references to other objects.
		 */
		public override void dispose () {
			try {
				if (!head_written) {
					size_t bytes_written;
					write_head (out bytes_written);
				}
			} catch (IOError err) {
				warning ("could not write the head in the connection stream: %s", err.message);
			} finally {
				base.dispose ();
			}
		}
	}
}
