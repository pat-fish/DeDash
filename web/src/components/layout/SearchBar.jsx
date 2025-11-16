

import { MagnifyingGlassIcon } from '@heroicons/react/24/outline';

export default function SearchBar() {
    return (
        <div className="flex items-center bg-silver px-4 py-2 border border-brown rounded-full
                        focus-within:ring-2 focus-within:ring-purple-500 focus-within:border-transparent">
            <MagnifyingGlassIcon className="h-6 w-6 text-black" />
            <input
                type="text"
                placeholder="Search..."
                className="ml-2 flex-1 bg-transparent outline-none"
            />
        </div>
    );
}