"use client";

import { UserIcon } from '@heroicons/react/24/solid';

export default function UserMenu({ onClick }) {
    return (
        <button
            onClick={onClick}
            className="w-10 h-10 bg-purple rounded-full flex items-center justify-center text-white cursor-pointer hover:bg-purple-700 transition"
        >
        <UserIcon className="w-6 h-6 text-white" />
        </button>
    );
}