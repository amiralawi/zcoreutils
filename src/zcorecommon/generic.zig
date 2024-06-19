

pub fn ringBuffer(comptime T: type) type {
    return struct{
        const Self = @This();
        const peekPtrIterator = struct{
            i: usize = 0,
            container: *Self,
            pub fn next(self: *@This()) ?*T{
                const i_get = self.i;
                self.i += 1;
                return self.container.peekPtr(i_get);
            }
        };
        const peekIterator = struct{
            i: usize = 0,
            container: *Self,
            pub fn next(self: *@This()) ?T{
                const i_get = self.i;
                self.i += 1;
                return self.container.peek(i_get);
            }
        };
        buffer: []T,
        iread: usize,// = 0,
        iwrite: usize,// = 0,

        pub fn init(buffer: []T) Self {
            // TODO - guard against empty buffer argument (this causes problems due to
            //        mod-by-zero problems in indexing)
            return .{
                .buffer = buffer,
                .iread = 0,
                .iwrite = 0,
            };
        }

        pub fn isEmpty(self: *@This()) bool {
            return self.iread == self.iwrite;
        }

        pub fn isFull(self: *@This()) bool {
            return self.size() == self.buffer.len;
        }

        pub fn size(self: *@This()) usize {
            if(self.iwrite < self.iread){
                return self.iwrite + 2*self.buffer.len - self.iread;
            }
            return self.iwrite - self.iread;
        }

        pub fn write(self: *@This(), newval: T) void{
            if(self.isFull()){
                return;
            }
            self.buffer[self.iwrite % self.buffer.len] = newval;
            self.iwrite = (self.iwrite + 1) % (2*self.buffer.len);
        }
        

        pub fn writeForce(self: *@This(), newval: T) ?T {
            if(self.isFull()){
                const bumped_val = self.read();
                self.write(newval);
                return bumped_val;
            }

            self.write(newval);
            return null;
        }

        pub fn grow(self: *@This()) ?*T {
            if(self.isFull()){
                return null;
            }
            //self.buffer[self.iwrite % self.buffer.len] = newval;
            self.iwrite = (self.iwrite + 1) % (2*self.buffer.len);
            return self.peekPtr(self.size() - 1);

        }

        pub fn read(self: *@This()) ?T {
            if(self.size() == 0){
                return null;
            }

            const i_ret = self.iread;
            self.iread = (self.iread + 1) % (2*self.buffer.len);
            return self.buffer[i_ret % self.buffer.len];
        }

        pub fn peekPtr(self: *@This(), i: usize) ?*T {
            if(i >= self.size()){
                return null;
            }
            return &self.buffer[(self.iread + i) % self.buffer.len];
        }
        pub fn peek(self: *@This(), i: usize) ?T {
            if(i >= self.size()){
                return null;
            }
            return self.buffer[(self.iread + i) % self.buffer.len];
        }
        pub fn peekItems(self: *@This(), ) peekIterator{
            return peekIterator{.container = self};
        }
        pub fn peekPtrItems(self: *@This(), ) peekPtrIterator{
            return peekPtrIterator{.container = self};
        }
    };
}